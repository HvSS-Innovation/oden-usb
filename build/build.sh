#!/usr/bin/env bash
# fetch -> verify -> live-build (i container) -> build/out/oden.iso
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p out

[[ "${1:-}" == "--offline" ]] || ./fetch.sh
# Verifiera igen offline: bygget ska misslyckas om något avviker.
while read -r name _ sha _; do
  [[ -z "${name:-}" || "$name" == \#* ]] && continue
  [[ "$sha" == BUILD ]] && continue
  [[ "$sha" == PENDING ]] && { echo "FEL: $name är inte låst" >&2; exit 1; }
  echo "$sha  cache/$name" | sha256sum -c --quiet || { echo "FEL: $name avviker" >&2; exit 1; }
done < artifacts.lock

# Oden för Linux finns inte som release: bygg från källa (kräver nät för pip) om den saknas i cache/.
if [[ ! -f cache/oden-linux ]]; then
  [[ "${1:-}" == "--offline" ]] && { echo "FEL: cache/oden-linux saknas och --offline kan inte bygga den" >&2; exit 1; }
  scripts/build-oden.sh
fi

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
{ cat out/lb/chroot/usr/share/oden/SBOM-packages.txt 2>/dev/null; echo "--- artefakter"; grep -v '^#' artifacts.lock
  echo "--- oden-linux (byggd) sha256: $(sha256sum cache/oden-linux | cut -d' ' -f1)"
  echo "--- Python-paket i oden-linux"; cat cache/oden-linux.pip-freeze.txt 2>/dev/null; } > out/SBOM.txt

# live-build (grub-efi + iso-hybrid) ger en ren El Torito-ISO utan MBR/GPT, som inte bootar från dd:ad USB.
# Efterbehandla: GPT med p1 = ISO-data och p2 = EFI-partition (efi.img), så att bilden är USB-bootbar
# och har exakt två partitioner (make-stick.sh lägger p3/p4 efter dem).
shopt -s nullglob
imgs=(out/lb/live-image-*.iso)
[[ ${#imgs[@]} -eq 1 ]] || { echo "FEL: förväntade en live-image-*.iso i out/lb, hittade ${#imgs[@]}" >&2; exit 1; }
rm -rf out/hybrid && mkdir -p out/hybrid && cp "${imgs[0]}" out/hybrid/in.iso
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD/out/hybrid":/w -w /w oden-builder sh -ec '
  xorriso -osirrox on -indev in.iso -extract /boot/grub/efi.img efi.img
  chmod u+w efi.img
  xorriso -indev in.iso -outdev out.iso -boot_image any replay \
    -append_partition 2 0xef efi.img -boot_image any appended_part_as=gpt \
    -boot_image any partition_offset=16 -map efi.img /boot/grub/efi.img -commit'
[[ $(sfdisk -d out/hybrid/out.iso | grep -c ': start=') -eq 2 ]] || { echo "FEL: hybridbilden har inte exakt 2 partitioner" >&2; exit 1; }
mv out/hybrid/out.iso out/oden.iso && rm -rf out/hybrid
echo "Klart: build/out/oden.iso, build/out/SBOM.txt"
