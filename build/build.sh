#!/usr/bin/env bash
# fetch -> verify -> live-build (i container) -> build/out/oden.iso (+ valfria varianter, se ODEN_VARIANTS)
# Bygget kräver nät (docker build, debootstrap/apt i live-build, pip). --no-fetch hoppar bara över fetch.sh:
# artefakterna måste redan ligga i cache/. Det är stickan som ska gå att köra offline, inte bygget.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p out

# Varianter ut över basbilden out/oden.iso (den används av make-stick.sh). ODEN_VARIANTS=minimal,karta,karta-ai eller all.
#   minimal   basbilden + maps.lock (kartor hämtas vid första start)
#   karta     + $ODEN_ASSETS/maps       karta-ai  + $ODEN_ASSETS/maps och $ODEN_ASSETS/ollama
assets="${ODEN_ASSETS:-$PWD/cache/assets}"
variants="${ODEN_VARIANTS:-}"; [[ "$variants" == all ]] && variants=minimal,karta,karta-ai
nonempty() { [[ -d "$1" && -n "$(ls -A "$1")" ]]; }
for v in ${variants//,/ }; do   # kontrolleras före det långa bygget
  case "$v" in
    minimal) grep -qv '^#' maps.lock 2>/dev/null && ! grep -q PENDING maps.lock || { echo "FEL: minimal kräver ifyllda rader i maps.lock (inga PENDING)" >&2; exit 1; } ;;
    karta) nonempty "$assets/maps" || { echo "FEL: karta kräver filer i $assets/maps" >&2; exit 1; } ;;
    karta-ai) nonempty "$assets/maps" && nonempty "$assets/ollama" || { echo "FEL: karta-ai kräver filer i $assets/maps och $assets/ollama" >&2; exit 1; } ;;
    *) echo "FEL: okänd variant $v (minimal, karta, karta-ai)" >&2; exit 1 ;;
  esac
done

[[ "${1:-}" == "--no-fetch" ]] || ./fetch.sh
# Verifiera artefakterna i cache/ mot låset: bygget ska misslyckas om något avviker.
while read -r name _ sha _; do
  [[ -z "${name:-}" || "$name" == \#* ]] && continue
  [[ "$sha" == BUILD ]] && continue
  [[ "$sha" == PENDING ]] && { echo "FEL: $name är inte låst" >&2; exit 1; }
  echo "$sha  cache/$name" | sha256sum -c --quiet || { echo "FEL: $name avviker" >&2; exit 1; }
done < artifacts.lock

# Oden för Linux finns inte som release: bygg från källa (kräver nät för pip) om den saknas i cache/
# eller om låsraderna för oden-source, jre-x64 och signal-cli ändrats sedan den byggdes.
if [[ ! -f cache/oden-linux ]] || [[ "$(cat cache/oden-linux.inputs 2>/dev/null)" != "$(scripts/build-oden.sh --print-inputs)" ]]; then
  [[ "${1:-}" == "--no-fetch" ]] && { echo "FEL: cache/oden-linux saknas eller är byggd från andra indata än artifacts.lock, och --no-fetch kan inte bygga den (kräver nät för pip)" >&2; exit 1; }
  rm -f cache/oden-linux
  scripts/build-oden.sh
fi

docker build -t oden-builder .

# live-build kör i out/lb; config och overlay kopieras in färska varje bygge.
# Container-bygget körs som root; out/lb chownas tillbaka efteråt, men en rootägd rest från ett äldre bygge städas via containern.
rm -rf out/lb 2>/dev/null || docker run --rm -v "$PWD/out":/o oden-builder rm -rf /o/lb
mkdir -p out/lb
cp -r config/. out/lb/
mkdir -p out/lb/config/includes.chroot
cp -r overlay/. out/lb/config/includes.chroot/
scripts/stage.sh out/lb/config/includes.chroot

docker run --rm --privileged -e OWNER="$(id -u):$(id -g)" -v "$PWD/out/lb":/lb -w /lb oden-builder \
  sh -c 'rc=0; lb config && lb build || rc=$?; chown -R "$OWNER" /lb; exit $rc'

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
mv out/hybrid/out.iso out/oden.iso

# Varianter: samma bild + extra filer i ISO-trädet (inget nytt live-build). Filer över 4 GiB kräver -file_size_limit off.
version=$(git describe --tags --always --dirty 2>/dev/null || date +%Y%m%d)
for v in ${variants//,/ }; do
  case "$v" in
    minimal)  maps=(-map /lock/maps.lock /oden/assets.lock) ;;
    karta)    maps=(-map /assets/maps /maps) ;;
    karta-ai) maps=(-map /assets/maps /maps -map /assets/ollama /ollama) ;;
  esac
  out="oden-$v-$version.iso"; amount="$assets"; [[ -d "$amount" ]] || amount="$PWD"   # minimal behöver ingen assets-katalog
  echo "Bygger $out ..."
  docker run --rm --user "$(id -u):$(id -g)" -v "$PWD/out":/w -v "$amount":/assets:ro -v "$PWD":/lock:ro -w /w oden-builder \
    xorriso -indev oden.iso -outdev "$out" -boot_image any replay -file_size_limit off -- "${maps[@]}" -commit
  [[ $(sfdisk -d "out/$out" | grep -c ': start=') -eq 2 ]] || { echo "FEL: $out har inte exakt 2 partitioner" >&2; exit 1; }
  (cd out && sha256sum "$out" > "$out.sha256")
done
rm -rf out/hybrid
echo "Klart: build/out/oden.iso${variants:+, varianter: $variants}, build/out/SBOM.txt"
