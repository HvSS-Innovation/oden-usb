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

# Map View: bara den lokala kartservern (go-pmtiles på 127.0.0.1:8081, steg 05). CartoDB och OpenStreetMap tas bort ur valvmallen:
# de ringer ut på nätet. maxZoom = högsta riktiga zoomnivå (build/map.conf); därefter förstoras rutorna (letZoomBeyondMax).
MAP_MAXZOOM=14; [[ -f "$here/../map.conf" ]] && . "$here/../map.conf"
mv_data="$root/opt/oden-template/.obsidian/plugins/obsidian-map-view/data.json"
if [[ -f "$mv_data" ]]; then
  MAXZ="$MAP_MAXZOOM" python3 -I - "$mv_data" <<'PY'
import json, os, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["mapSources"] = [{"name": "ODEN (lokal karta)", "urlLight": "http://127.0.0.1:8081/sverige/{z}/{x}/{y}.webp", "maxZoom": int(os.environ["MAXZ"])}]
d["letZoomBeyondMax"] = True
d["cacheAllTiles"] = False
maxz = int(os.environ["MAXZ"])
def fix(st):
    if isinstance(st, dict) and "chosenMapSource" in st: st["chosenMapSource"] = 0
    # Startvyer över kartans sista nivå ger bara 404 ("Tile Unavailable"): kläm ner dem
    if isinstance(st, dict) and isinstance(st.get("mapZoom"), (int, float)) and st["mapZoom"] > maxz: st["mapZoom"] = maxz
fix(d.get("defaultState"))
for st in d.get("savedStates", []) or []: fix(st)
json.dump(d, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)

# Map View lägger själv tillbaka en källa som heter som pluginets standard (CartoDB) först i listan om den saknas, och då blir
# index 0 = CartoDB (externa anrop). Därför byts själva standardkällan i main.js mot den lokala; då räknas vår källa som den.
mj = os.path.join(os.path.dirname(p), "main.js")
src = open(mj, encoding="utf-8").read()
old = ("            name: 'CartoDB',\n"
       "            urlLight: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',\n"
       "            preset: true,")
new = ("            name: 'ODEN (lokal karta)',\n"
       "            urlLight: 'http://127.0.0.1:8081/sverige/{z}/{x}/{y}.webp',\n"
       "            maxZoom: %d,\n"
       "            preset: true," % maxz)
if src.count(old) != 1:
    sys.exit("FEL: Map Views standardkälla hittades inte i main.js (pluginet har ändrats; uppdatera patchen i stage.sh)")
src = src.replace(old, new)
if "cartocdn" in src:
    sys.exit("FEL: main.js innehåller fortfarande cartocdn")
open(mj, "w", encoding="utf-8").write(src)
PY
  grep -q 127.0.0.1:8081 "$mv_data" || { echo "FEL: kunde inte sätta lokal kartkälla i Map View" >&2; exit 1; }
  ! grep -qE "cartocdn|tile\.openstreetmap" "$mv_data" || { echo "FEL: Map View pekar fortfarande på externa kartservrar" >&2; exit 1; }
fi
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
