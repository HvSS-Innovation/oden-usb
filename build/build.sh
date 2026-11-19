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

# live-build kör i out/lb; config och overlay kopieras in färska varje bygge.
rm -rf out/lb && mkdir -p out/lb
cp -r config/. out/lb/
mkdir -p out/lb/config/includes.chroot
cp -r overlay/. out/lb/config/includes.chroot/
# TODO (steg 02): lägg artefakter från cache/ under includes.chroot/opt/*

docker run --rm --privileged -v "$PWD/out/lb":/lb -w /lb oden-builder \
  sh -c 'lb config && lb build'

# SBOM: paketdelen från bilden + artefaktlåset
{ cat out/lb/chroot/usr/share/oden/SBOM-packages.txt 2>/dev/null; echo "--- artefakter"; grep -v '^#' artifacts.lock; } > out/SBOM.txt
