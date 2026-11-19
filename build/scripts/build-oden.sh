#!/usr/bin/env bash
# Bygger Oden för Linux (PyInstaller, en enda körbar fil) -> build/cache/oden-linux
# Indata (låsta i artifacts.lock, hämtade av fetch.sh): oden-source, jre-x64, signal-cli.
# Kräver nät (pip) och docker. Bygget sker i Debian bookworm: binären kräver glibc <= bildens (trixie).
# build.sh bygger om automatiskt när låsraderna för indata ändrats (cache/oden-linux.inputs); radera cache/oden-linux för att tvinga.
set -euo pipefail
cd "$(dirname "$0")/.."
# Hash av de låsrader (namn, url, sha256) binären byggs från. build.sh jämför den med cache/oden-linux.inputs.
inputs_hash() { awk '$1 ~ /^(oden-source|jre-x64|signal-cli)$/ {print $1, $2, $3}' artifacts.lock | sha256sum | cut -d' ' -f1; }
[[ "${1:-}" == "--print-inputs" ]] && { inputs_hash; exit 0; }
for n in oden-source jre-x64 signal-cli; do
  [[ -f cache/$n ]] || { echo "FEL: cache/$n saknas (kör fetch.sh)" >&2; exit 1; }
done
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

docker run --rm -v "$PWD/cache":/cache:ro -v "$work":/work -e OWNER="$(id -u):$(id -g)" \
  python:3.12-bookworm bash -euc '
  trap '"'"'chown -R "$OWNER" /work'"'"' EXIT   # även vid fel: värdens städning ska fungera
  cd /work
  mkdir src; tar -xzf /cache/oden-source -C src --strip-components=1
  S=src; [ -f $S/s7_watcher.spec ] || { echo "s7_watcher.spec saknas i källan" >&2; exit 1; }
  mkdir $S/jre-x64 $S/signal-cli
  tar -xzf /cache/jre-x64 -C $S/jre-x64 --strip-components=1
  rm -rf $S/jre-x64/man $S/jre-x64/legal
  tar -xzf /cache/signal-cli -C $S/signal-cli --strip-components=1
  chmod +x $S/signal-cli/bin/signal-cli
  cd $S
  pip install --no-cache-dir ".[tak]" pyinstaller
  pyinstaller --clean --noconfirm s7_watcher.spec
  pip freeze > /work/pip-freeze.txt
  cp dist/oden /work/oden-linux
'
[[ -x "$work/oden-linux" ]] || { echo "FEL: bygget gav ingen dist/oden" >&2; exit 1; }
mv "$work/pip-freeze.txt" cache/oden-linux.pip-freeze.txt
mv "$work/oden-linux" cache/oden-linux
inputs_hash > cache/oden-linux.inputs
echo "build-oden: OK ($(du -h cache/oden-linux | cut -f1))"
