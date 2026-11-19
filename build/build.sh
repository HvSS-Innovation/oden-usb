#!/usr/bin/env bash
# fetch -> verify -> live-build (i container) -> build/out/oden.img
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p out

[[ "${1:-}" == "--offline" ]] || ./fetch.sh
# Verifiera igen offline: bygget ska misslyckas om något avviker.
while read -r name _ sha _; do
  [[ -z "${name:-}" || "$name" == \#* ]] && continue
  [[ "$sha" == PENDING ]] && { echo "FEL: $name är inte låst" >&2; exit 1; }
  echo "$sha  cache/$name" | sha256sum -c --quiet || { echo "FEL: $name avviker" >&2; exit 1; }
done < artifacts.lock

docker build -t oden-builder .

docker run --rm --privileged -v "$PWD":/work -w /work oden-builder \
  bash -c 'cd /work/out && lb clean --purge 2>/dev/null; cp -r /work/config /work/out/config && lb config && lb build'
# SBOM skrivs av hooken config/hooks/live/9000-sbom.hook.chroot
