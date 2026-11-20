#!/usr/bin/env bash
# Tester av byggskripten utan nät (inga riktiga artefakter, ingen root, ingen docker).
#   build/tests/run.sh
# Testar: syntax i alla skript, stage.sh med fejkade artefakter (positivt, saknad binär, falsk AppImage).
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FEL  $1" >&2; fail=1; }

for f in build.sh fetch.sh scripts/*.sh tests/run.sh overlay/usr/local/bin/oden-*; do
  bash -n "$f" && ok "syntax $f" || bad "syntax $f"
done

t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/c" "$t/w"; w="$t/w"
fake_cache() {   # fejkade artefakter med rätt format och layout
  rm -rf "$t/c"/* "$w"/*
  ( cd "$w"
    mkdir oden-1; printf '#!/bin/sh\n' > oden-1/oden; chmod +x oden-1/oden; tar czf "$t/c/oden-linux" oden-1
    mkdir -p v-1/.obsidian; echo n > v-1/note.md; echo c > v-1/.obsidian/app.json
    python3 -m zipfile -c "$t/c/oden-valv" v-1
    cp /bin/true pmtiles; tar czf "$t/c/go-pmtiles" pmtiles
    mkdir bin; cp /bin/true bin/ollama; tar czf "$t/c/ollama" bin )
  cat > "$t/c/obsidian-appimage" <<'APP'
#!/bin/sh
[ "$1" = --appimage-extract ] && mkdir -p squashfs-root && printf '#!/bin/sh\n' > squashfs-root/obsidian && chmod +x squashfs-root/obsidian
APP
}

fake_cache; mkdir "$t/root"
if CACHE="$t/c" scripts/stage.sh "$t/root" >/dev/null 2>&1 \
   && [[ -x $t/root/opt/oden/oden && -x $t/root/opt/obsidian/obsidian && -x $t/root/opt/pmtiles/pmtiles \
      && -x $t/root/opt/ollama/bin/ollama && -f $t/root/opt/oden-template/note.md \
      && -f $t/root/opt/oden-template/.obsidian/app.json && -s $t/root/etc/oden-release ]]
then ok "stage: positivt (flatten av oden/valv, ingen flatten av ollama)"; else bad "stage: positivt"; fi

fake_cache; rm -f "$t/c/go-pmtiles"; rm -rf "$t/root"; mkdir "$t/root"
if CACHE="$t/c" scripts/stage.sh "$t/root" >/dev/null 2>&1; then bad "stage: saknad artefakt ska ge fel"; else ok "stage: saknad artefakt avbryter"; fi

fake_cache; printf '#!/bin/sh\n' > "$t/c/obsidian-appimage"; rm -rf "$t/root"; mkdir "$t/root"
if CACHE="$t/c" scripts/stage.sh "$t/root" >/dev/null 2>&1; then bad "stage: falsk AppImage ska ge fel"; else ok "stage: falsk AppImage avbryter"; fi

for j in overlay/etc/firefox-esr/policies/policies.json overlay/etc/skel/.config/obsidian/obsidian.json; do
  python3 -m json.tool "$j" >/dev/null 2>&1 && ok "json $j" || bad "json $j"
done

pp() { printf '%s' "$1" | overlay/usr/local/bin/oden-passphrase-ok; }
pp "fyra vanliga ord pa rad" && ok "lösenfras: giltig godkänns" || bad "lösenfras: giltig godkänns"
pp "Hemligt lösenord 12345" && bad "lösenfras: å/ö avvisas" || ok "lösenfras: å/ö avvisas"
pp "tillrackligt-langt-men-bindestreck" && bad "lösenfras: symboler avvisas" || ok "lösenfras: symboler avvisas"
pp "abc" && ok "lösenfras: kort fras godkänns utan längdkrav" || bad "lösenfras: kort fras godkänns utan längdkrav"
printf %s "abc" | ODEN_MINLEN=16 overlay/usr/local/bin/oden-passphrase-ok && bad "lösenfras: ODEN_MINLEN kan ställa krav" || ok "lösenfras: ODEN_MINLEN kan ställa krav"
pp "" && bad "lösenfras: tom avvisas" || ok "lösenfras: tom avvisas"

# oden-hidpi: skala ur xrandr (fejkad), överstyrning via variabel och kärnparameter
mkdir -p "$t/xb"; hi="$PWD/overlay/usr/local/bin/oden-hidpi"
fx() { printf '#!/bin/sh\necho "Screen 0: minimum 320 x 200, current %s"\necho "%s"\n' "$1" "$2" > "$t/xb/xrandr"; chmod +x "$t/xb/xrandr"; }
fx "2880 x 1800" "eDP-1 connected primary 2880x1800+0+0 (normal left inverted right x axis y axis) 331mm x 207mm"
[[ "$(PATH="$t/xb:$PATH" ODEN_CMDLINE=/dev/null "$hi" scale)" == 2 ]] && ok "hidpi: retina (2880x1800, 331 mm) ger skala 2" || bad "hidpi: retina ger skala 2"
fx "1920 x 1080" "eDP-1 connected primary 1920x1080+0+0 (normal left inverted right x axis y axis) 344mm x 194mm"
[[ "$(PATH="$t/xb:$PATH" ODEN_CMDLINE=/dev/null "$hi" scale)" == 1 ]] && ok "hidpi: 1080p ger skala 1" || bad "hidpi: 1080p ger skala 1"
fx "3840 x 2160" "HDMI-1 connected 3840x2160+0+0 (normal left inverted right x axis y axis) 1600mm x 900mm"
[[ "$(PATH="$t/xb:$PATH" ODEN_CMDLINE=/dev/null "$hi" scale)" == 1 ]] && ok "hidpi: stor 4K-TV (låg täthet) ger skala 1" || bad "hidpi: 4K-TV ger skala 1"
[[ "$(PATH="$t/xb:$PATH" ODEN_SCALE=2 "$hi" scale)" == 2 ]] && ok "hidpi: ODEN_SCALE överstyr" || bad "hidpi: ODEN_SCALE överstyr"
echo "boot=live oden.scale=2 quiet" > "$t/cmdline"
[[ "$(PATH="$t/xb:$PATH" ODEN_CMDLINE="$t/cmdline" "$hi" scale)" == 2 ]] && ok "hidpi: oden.scale på kärnraden överstyr" || bad "hidpi: oden.scale på kärnraden"
PATH="/usr/bin:/bin" ODEN_CMDLINE=/dev/null "$hi" scale 2>/dev/null | grep -qx 1 && ok "hidpi: utan xrandr blir skala 1" || bad "hidpi: utan xrandr"

# oden-keyboard: Mac-layout bara på Apple
printf '#!/bin/sh\necho "$@" > "%s/xkb"\n' "$t" > "$t/fakexkb"; chmod +x "$t/fakexkb"
echo "Apple Inc." > "$t/vend"; rm -f "$t/xkb"
ODEN_DMI_VENDOR="$t/vend" ODEN_SETXKBMAP="$t/fakexkb" overlay/usr/local/bin/oden-keyboard
grep -q -- "-layout se -variant mac" "$t/xkb" 2>/dev/null && ok "keyboard: Apple får se(mac)" || bad "keyboard: Apple får se(mac)"
echo "LENOVO" > "$t/vend"; rm -f "$t/xkb"
ODEN_DMI_VENDOR="$t/vend" ODEN_SETXKBMAP="$t/fakexkb" overlay/usr/local/bin/oden-keyboard
[[ ! -e "$t/xkb" ]] && ok "keyboard: annan tillverkare lämnas orörd" || bad "keyboard: annan tillverkare"

# stage: Map View får bara den lokala kartkällan (inga externa tileservrar)
fake_cache; ( cd "$w" && mkdir -p v-2/.obsidian/plugins/obsidian-map-view && echo n > v-2/note.md
  echo '{"mapSources":[{"name":"CartoDB","urlLight":"https://a.basemaps.cartocdn.com/x/{z}/{x}/{y}.png","preset":true},{"name":"OSM","urlLight":"https://tile.openstreetmap.org/{z}/{x}/{y}.png"}],"letZoomBeyondMax":false,"cacheAllTiles":true,"defaultState":{"chosenMapSource":1},"savedStates":[{"chosenMapSource":1}]}' > v-2/.obsidian/plugins/obsidian-map-view/data.json
  python3 -m zipfile -c "$t/c/oden-valv" v-2 ); rm -rf "$t/root"; mkdir "$t/root"
CACHE="$t/c" scripts/stage.sh "$t/root" >/dev/null 2>&1
mvd="$t/root/opt/oden-template/.obsidian/plugins/obsidian-map-view/data.json"
python3 -I - "$mvd" <<'PY' && ok "stage: Map View använder bara lokal karta (maxZoom ur map.conf)" || bad "stage: Map View-källa"
import json, sys
d = json.load(open(sys.argv[1]))
assert len(d["mapSources"]) == 1 and d["mapSources"][0]["urlLight"].startswith("http://127.0.0.1:8081/")
assert d["mapSources"][0]["maxZoom"] == 12 and d["letZoomBeyondMax"] is True and d["cacheAllTiles"] is False
assert d["defaultState"]["chosenMapSource"] == 0 and d["savedStates"][0]["chosenMapSource"] == 0
PY

# stage: release-tarball med en platt binär (som Odens Linux-release) hamnar i opt/oden/oden
fake_cache; ( cd "$w" && mkdir flat && printf '#!/bin/sh\n' > flat/oden && chmod +x flat/oden && tar -C flat -czf "$t/c/oden-linux" oden ); rm -rf "$t/root"; mkdir "$t/root"
CACHE="$t/c" scripts/stage.sh "$t/root" >/dev/null 2>&1 && [[ -x "$t/root/opt/oden/oden" ]] && ok "stage: release-tarball med platt binär" || bad "stage: release-tarball med platt binär"

if command -v sgdisk >/dev/null; then
  mk() { rm -f "$t/d.img"; truncate -s "$1" "$t/d.img"; sgdisk -n 1:2048:+10M -n 2:0:+2M "$t/d.img" >/dev/null; sgdisk -e "$t/d.img" >/dev/null 2>&1 || true
         truncate -s "$2" "$t/d.img"; }
  mp() { ODEN_DISK="$t/d.img" ODEN_NOPARTX=1 ODEN_MINFREE_MB=8 overlay/usr/local/bin/oden-make-persist; }
  mk 20M 64M
  if mp 2>/dev/null && sgdisk -p "$t/d.img" | awk '$NF=="persistence"' | grep -q . && sgdisk -v "$t/d.img" | grep -q "No problems"; then
    ok "make-persist: skapar partition och GPT är giltig"; else bad "make-persist: skapar partition"; fi
  mp 2>/dev/null && [[ $(sgdisk -p "$t/d.img" | awk '$NF=="persistence"' | wc -l) -eq 1 ]] \
    && ok "make-persist: andra körningen gör inget" || bad "make-persist: idempotent"
  mk 20M 18M
  mp 2>/dev/null && bad "make-persist: för lite utrymme ska ge fel" || ok "make-persist: för lite utrymme avvisas"
else
  echo "hoppar över make-persist-tester (sgdisk saknas)"
fi

# oden-assets-bind: binder maps/ollama från mediet; hoppar över tomma/saknade kataloger.
mkdir -p "$t/med/maps" "$t/med/ollama" "$t/as"; touch "$t/med/maps/sverige.pmtiles"
printf '#!/bin/sh\necho "$@" >> "%s/mounts"\n' "$t" > "$t/fakemount"; chmod +x "$t/fakemount"
ODEN_MEDIUM="$t/med" ODEN_ASSETS="$t/as" ODEN_MOUNT="$t/fakemount" overlay/usr/local/bin/oden-assets-bind
if grep -q -- "--bind $t/med/maps $t/as/maps" "$t/mounts" && grep -q "remount,bind,ro $t/as/maps" "$t/mounts" \
   && ! grep -q ollama "$t/mounts"; then ok "assets-bind: binder maps, hoppar över tom ollama"; else bad "assets-bind"; fi

# make-persist med assets.lock: assets-partitionen skapas före persistensen.
if command -v sgdisk >/dev/null; then
  printf 'maps/x.pmtiles http://x/x 00 %s\n' 3000000 > "$t/lock"
  mk 20M 600M
  ODEN_LOCK="$t/lock" mp 2>/dev/null || true; out=$(sgdisk -p "$t/d.img")
  if grep -q oden-assets <<<"$out" && grep -q persistence <<<"$out" \
     && [[ $(awk '$NF=="oden-assets" {print $1}' <<<"$out") -lt $(awk '$NF=="persistence" {print $1}' <<<"$out") ]]
  then ok "make-persist: assets före persistens när lock finns"; else bad "make-persist: assets med lock"; fi
fi

# oden-fetch-assets: fejkad curl kopierar en lokal fil.
printf '#!/bin/bash\nwhile [[ $# -gt 0 ]]; do case "$1" in -o) o=$2; shift;; -*) ;; *) u=$1;; esac; shift; done\ncp "$u" "$o"\n' > "$t/fakecurl"; chmod +x "$t/fakecurl"
head -c 5000 /dev/zero > "$t/src.bin"; sum=$(sha256sum "$t/src.bin" | cut -d' ' -f1)
fa() { ODEN_NOGUI=1 ODEN_CURL="$t/fakecurl" ODEN_LOCK="$t/fl" ODEN_ASSETS="$t/fa" overlay/usr/local/bin/oden-fetch-assets; }
rm -rf "$t/fa"; mkdir "$t/fa"
echo "maps/sverige.pmtiles $t/src.bin $sum 5000" > "$t/fl"
fa 2>/dev/null && [[ -f $t/fa/maps/sverige.pmtiles && ! -e $t/fa/maps/sverige.pmtiles.part ]] \
  && ok "fetch-assets: hämtar och kontrollerar SHA256" || bad "fetch-assets: positivt"
echo "maps/sverige.pmtiles $t/src.bin $sum 5000" > "$t/fl"; rm -rf "$t/fa"; mkdir "$t/fa"
echo "maps/sverige.pmtiles $t/src.bin deadbeef 5000" > "$t/fl"
if fa 2>/dev/null; then bad "fetch-assets: fel SHA256 ska ge fel"; else
  [[ ! -e $t/fa/maps/sverige.pmtiles && ! -e $t/fa/maps/sverige.pmtiles.part ]] && ok "fetch-assets: fel SHA256 avvisas och rensas" || bad "fetch-assets: rester kvar"; fi
rm -f "$t/fl"; fa && ok "fetch-assets: utan lista gör den inget" || bad "fetch-assets: utan lista"

# release-json.sh: JSON från fejkade ISO-filer.
mkdir -p "$t/rel"; head -c 1000 /dev/zero > "$t/rel/oden-karta-abc123.iso"
(cd "$t/rel" && sha256sum oden-karta-abc123.iso > oden-karta-abc123.iso.sha256)
if scripts/release-json.sh https://x.example/d "$t/rel" | python3 -c 'import json,sys; d=json.load(sys.stdin)["isos"][0]; assert d["variant"]=="karta" and d["bytes"]==1000 and d["url"]=="https://x.example/d/oden-karta-abc123.iso" and len(d["sha256"])==64'
then ok "release-json: variant, url, storlek och sha256"; else bad "release-json"; fi
rm "$t/rel/oden-karta-abc123.iso.sha256"
scripts/release-json.sh https://x.example/d "$t/rel" >/dev/null 2>&1 && bad "release-json: saknad .sha256 ska ge fel" || ok "release-json: saknad .sha256 avvisas"
python3 -m json.tool ../site/releases.json >/dev/null && ok "json site/releases.json" || bad "json site/releases.json"

exit $fail
