#!/usr/bin/env bash
# Bygger Oden för Linux (PyInstaller) -> build/cache/oden-linux. Onedir (tarball med katalogen oden/) om källan stöder ODEN_ONEDIR=1
# (Oden efter PR #304), annars en enda körbar fil (onefile, packar upp ca 200 MB i RAM vid varje start).
# Indata (låsta i artifacts.lock, hämtade av fetch.sh): oden-source, jre-x64, signal-cli.
# Kräver nät (pip) och docker. Bygget sker i Debian bookworm: binären kräver glibc <= bildens (trixie).
# build.sh bygger om automatiskt när låsraderna för indata ändrats (cache/oden-linux.inputs); radera cache/oden-linux för att tvinga.
set -euo pipefail
cd "$(dirname "$0")/.."
# Hash av de låsrader (namn, url, sha256) binären byggs från. build.sh jämför den med cache/oden-linux.inputs.
# stamp-version-N: ändras när byggsteget ändras så att cache/oden-linux byggs om.
inputs_hash() { { awk '$1 ~ /^(oden-source|jre-x64|signal-cli)$/ {print $1, $2, $3}' artifacts.lock; echo stamp-version-2; } | sha256sum | cut -d' ' -f1; }
# Version = "version=X" i kommentaren på oden-source-raden (används för commit-tarballs), annars taggen i URL:en
# (…/tags/v4.2.1.tar.gz -> 4.2.1).
ODEN_VERSION=$(awk '$1=="oden-source" { for (i=4;i<=NF;i++) if ($i ~ /^version=/) { sub(/^version=/,"",$i); print $i; exit } print $2 }' artifacts.lock | sed -E 's#.*/tags/v?##; s#\.tar\.gz$##')
[[ "$ODEN_VERSION" =~ ^[0-9][0-9A-Za-z.+-]*$ ]] || { echo "FEL: kunde inte läsa version ur oden-source-URL:en ($ODEN_VERSION)" >&2; exit 1; }
[[ "${1:-}" == "--print-inputs" ]] && { inputs_hash; exit 0; }
for n in oden-source jre-x64 signal-cli; do
  [[ -f cache/$n ]] || { echo "FEL: cache/$n saknas (kör fetch.sh)" >&2; exit 1; }
done
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

docker run --rm -v "$PWD/cache":/cache:ro -v "$work":/work -e OWNER="$(id -u):$(id -g)" -e ODEN_VERSION="$ODEN_VERSION" -e ODEN_ONEDIR=1 \
  python:3.12-bookworm bash -euc '
  trap '"'"'chown -R "$OWNER" /work'"'"' EXIT   # även vid fel: värdens städning ska fungera
  cd /work
  mkdir src; tar -xzf /cache/oden-source -C src --strip-components=1
  S=src
  # Källan har __version__ = 0.0.0-dev; Odens release-workflow stämplar versionen på samma sätt (taggen ur låset).
  sed -i "s/__version__ = \".*\"/__version__ = \"$ODEN_VERSION\"/" $S/oden/__init__.py
  [ -f $S/s7_watcher.spec ] || { echo "s7_watcher.spec saknas i källan" >&2; exit 1; }
  mkdir $S/jre-x64 $S/signal-cli
  tar -xzf /cache/jre-x64 -C $S/jre-x64 --strip-components=1
  rm -rf $S/jre-x64/man $S/jre-x64/legal
  tar -xzf /cache/signal-cli -C $S/signal-cli --strip-components=1
  chmod +x $S/signal-cli/bin/signal-cli
  cd $S
  pip install --no-cache-dir ".[tak]" pyinstaller
  pyinstaller --clean --noconfirm s7_watcher.spec
  pip freeze > /work/pip-freeze.txt
  if [ -d dist/oden ]; then tar -C dist -czf /work/oden-linux oden; echo onedir > /work/oden-linux.kind; else cp dist/oden /work/oden-linux; echo onefile > /work/oden-linux.kind; fi
'
[[ -s "$work/oden-linux" ]] || { echo "FEL: bygget gav ingen dist/oden" >&2; exit 1; }
mv "$work/pip-freeze.txt" cache/oden-linux.pip-freeze.txt
mv "$work/oden-linux" cache/oden-linux
kind=$(cat "$work/oden-linux.kind")
inputs_hash > cache/oden-linux.inputs
echo "build-oden: OK ($kind, $(du -h cache/oden-linux | cut -f1))"
