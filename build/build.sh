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
scripts/stage.sh out/lb/config/includes.chroot

docker run --rm --privileged -v "$PWD/out/lb":/lb -w /lb oden-builder \
  sh -c 'lb config && lb build'

# SBOM: paketdelen från bilden + artefaktlåset
{ cat out/lb/chroot/usr/share/oden/SBOM-packages.txt 2>/dev/null; echo "--- artefakter"; grep -v '^#' artifacts.lock; } > out/SBOM.txt

# Bilden: live-build skriver live-image-<arch>.img (binary-image hdd)
shopt -s nullglob
imgs=(out/lb/live-image-*.img)
[[ ${#imgs[@]} -eq 1 ]] || { echo "FEL: förväntade en live-image-*.img i out/lb, hittade ${#imgs[@]}" >&2; exit 1; }
mv "${imgs[0]}" out/oden.img
echo "Klart: build/out/oden.img, build/out/SBOM.txt"
