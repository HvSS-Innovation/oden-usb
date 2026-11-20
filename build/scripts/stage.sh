#!/usr/bin/env bash
# Packar upp artefakterna i build/cache/ till rätt plats under includes.chroot/opt/ och
# skriver versionsstämpeln. Körs av build.sh efter checksumkontrollen. Offline.
#   stage.sh <includes.chroot-katalog>
# Format avgörs av filens första byte (artefakterna i cache/ saknar filändelse):
#   tar/gzip -> packas upp, zip -> packas upp, ELF -> kopieras (AppImage: --appimage-extract)
# Efteråt kontrolleras att de binärer som unit-filerna förväntar sig finns; annars avbryts bygget.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cache="${CACHE:-$here/../cache}"
root="$(readlink -f "${1:?includes.chroot-katalog saknas}")"
for t in tar od; do command -v "$t" >/dev/null || { echo "Verktyget $t saknas" >&2; exit 1; }; done

# Om uppackningen gav exakt en katalog och inget annat (t.ex. ODEN-valv-1.2/): lyft upp innehållet.
flatten() {
  local d="$1" n
  n=$(find "$d" -mindepth 1 -maxdepth 1 | wc -l)
  if [[ $n -eq 1 && -d "$(find "$d" -mindepth 1 -maxdepth 1)" ]]; then
    local sub; sub=$(find "$d" -mindepth 1 -maxdepth 1)
    mv "$sub"/* "$sub"/.[!.]* "$d"/ 2>/dev/null || true
    rmdir "$sub"
  fi
}

# unpack <artefakt> <målkatalog under opt/> [flatten]   (flatten: lyft upp en ensam toppkatalog)
unpack() {
  local f="$cache/$1" dest="$root/opt/$2"
  [[ -f "$f" ]] || { echo "FEL: $f saknas (kör fetch.sh)" >&2; exit 1; }
  rm -rf "$dest"; mkdir -p "$dest"
  case "$(head -c4 "$f" | od -An -tx1 | tr -d ' \n')" in
    1f8b*|fd377a58|28b52ffd) tar -xf "$f" -C "$dest" ;;   # gzip, xz, zstd
    504b0304) if command -v unzip >/dev/null; then unzip -q "$f" -d "$dest"; else python3 -m zipfile -e "$f" "$dest"; fi ;;  # zip
    7f454c46) install -m 755 "$f" "$dest/$(basename "$2")" ;;  # ELF
    *) echo "FEL: okänt format på $1" >&2; exit 1 ;;
  esac
  [[ "${3:-}" == flatten ]] && flatten "$dest"
  return 0
}

unpack oden-linux oden flatten
unpack oden-valv oden-template flatten
unpack go-pmtiles pmtiles
unpack ollama ollama

# Obsidian: AppImage extraheras (FUSE behövs inte på stickan).
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cp "$cache/obsidian-appimage" "$tmp/obsidian.AppImage"; chmod +x "$tmp/obsidian.AppImage"
(cd "$tmp" && ./obsidian.AppImage --appimage-extract >/dev/null)
[[ -d "$tmp/squashfs-root" ]] || { echo "FEL: AppImagen gav ingen squashfs-root vid --appimage-extract" >&2; exit 1; }
rm -rf "$root/opt/obsidian"; mkdir -p "$root/opt"
mv "$tmp/squashfs-root" "$root/opt/obsidian"
# mktemp -d ger läge 700: utan detta kan användaren oden inte ens gå in i /opt/obsidian (Obsidian startar inte).
chmod -R u+rwX,go+rX "$root/opt"

# Kontroll: det som unit-filer och autostart pekar på.
for p in opt/oden/oden opt/obsidian/obsidian opt/pmtiles/pmtiles opt/ollama/bin/ollama; do
  [[ -x "$root/$p" ]] || { echo "FEL: /$p saknas eller är inte körbar efter uppackning; kontrollera artefaktens layout" >&2; exit 1; }
done
[[ -n "$(ls -A "$root/opt/oden-template")" ]] || { echo "FEL: valvmallen är tom" >&2; exit 1; }

# Versionsstämpel (visas av oden-release / kan läsas i Obsidian-valvet): datum + lås-checksumma.
mkdir -p "$root/etc"
{
  echo "ODEN-stick $(date -u +%Y-%m-%d)"
  echo "artifacts.lock sha256: $(sha256sum "$here/../artifacts.lock" | cut -d' ' -f1)"
} > "$root/etc/oden-release"
echo "stage: OK"
