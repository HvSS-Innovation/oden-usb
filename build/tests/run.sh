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
# Egen PATH med bara det skriptet behöver: /usr/bin har xrandr på en dator med skrivbord.
mkdir -p "$t/noxr"; for c in cat awk; do ln -s "$(command -v $c)" "$t/noxr/$c"; done
PATH="$t/noxr" ODEN_SCALEFILE=/dev/null ODEN_CMDLINE=/dev/null "$hi" scale 2>/dev/null | grep -qx 1 && ok "hidpi: utan xrandr blir skala 1" || bad "hidpi: utan xrandr"

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
  printf "mapSources: [\\n        {\\n            name: 'CartoDB',\\n            urlLight: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',\\n            preset: true,\\n        },\\n    ],\\n" > v-2/.obsidian/plugins/obsidian-map-view/main.js
  echo '{"mapSources":[{"name":"CartoDB","urlLight":"https://a.basemaps.cartocdn.com/x/{z}/{x}/{y}.png","preset":true},{"name":"OSM","urlLight":"https://tile.openstreetmap.org/{z}/{x}/{y}.png"}],"letZoomBeyondMax":false,"cacheAllTiles":true,"defaultState":{"chosenMapSource":1,"mapZoom":14},"savedStates":[{"chosenMapSource":1,"mapZoom":9}]}' > v-2/.obsidian/plugins/obsidian-map-view/data.json
  python3 -m zipfile -c "$t/c/oden-valv" v-2 ); rm -rf "$t/root"; mkdir "$t/root"
CACHE="$t/c" scripts/stage.sh "$t/root" >/dev/null 2>&1
mvd="$t/root/opt/oden-template/.obsidian/plugins/obsidian-map-view/data.json"
MAXZ=$(sed -n 's/^MAP_MAXZOOM=//p' map.conf)
MAXZ="$MAXZ" python3 -I - "$mvd" <<'PY' && ok "stage: Map View använder bara lokal karta (maxZoom ur map.conf)" || bad "stage: Map View-källa"
import json, sys, os
Z = int(os.environ["MAXZ"])
d = json.load(open(sys.argv[1]))
assert len(d["mapSources"]) == 1 and d["mapSources"][0]["urlLight"].startswith("http://127.0.0.1:8081/")
assert d["mapSources"][0]["maxZoom"] == Z and d["letZoomBeyondMax"] is True and d["cacheAllTiles"] is False
assert d["defaultState"]["chosenMapSource"] == 0 and d["savedStates"][0]["chosenMapSource"] == 0
assert d["defaultState"]["mapZoom"] == min(14, Z) and d["savedStates"][0]["mapZoom"] == 9   # nedkläm bara det som är för högt
mj = open(sys.argv[1].replace("data.json", "main.js")).read()
assert "cartocdn" not in mj and "127.0.0.1:8081" in mj and f"maxZoom: {Z}" in mj
PY

# stage: release-tarball med en platt binär (som Odens Linux-release) hamnar i opt/oden/oden
fake_cache; ( cd "$w" && mkdir flat && printf '#!/bin/sh\n' > flat/oden && chmod +x flat/oden && tar -C flat -czf "$t/c/oden-linux" oden ); rm -rf "$t/root"; mkdir "$t/root"
CACHE="$t/c" scripts/stage.sh "$t/root" >/dev/null 2>&1 && [[ -x "$t/root/opt/oden/oden" ]] && ok "stage: release-tarball med platt binär" || bad "stage: release-tarball med platt binär"

# stage: onedir-tarball (katalogen oden/ med binären oden och _internal/) -> opt/oden/oden och opt/oden/_internal
fake_cache; ( cd "$w" && rm -rf od && mkdir -p od/oden/_internal && printf '#!/bin/sh\n' > od/oden/oden && chmod +x od/oden/oden && echo x > od/oden/_internal/lib.so && tar -C od -czf "$t/c/oden-linux" oden ); rm -rf "$t/root"; mkdir "$t/root"
CACHE="$t/c" scripts/stage.sh "$t/root" >/dev/null 2>&1 && [[ -x "$t/root/opt/oden/oden" && -f "$t/root/opt/oden/_internal/lib.so" ]] && ok "stage: onedir-tarball" || bad "stage: onedir-tarball"
[[ -s "$t/root/etc/oden-versions" ]] && ! grep -q BUILD "$t/root/etc/oden-versions" && grep -q '^oden-source ' "$t/root/etc/oden-versions" \
  && ok "stage: /etc/oden-versions ur artifacts.lock" || bad "stage: /etc/oden-versions"

# oden-admin: hjälp, menyn avslutas med 0, delkommandon kör utan att kräva nätverk eller root
oa=overlay/usr/local/bin/oden-admin
"$oa" hjalp | grep -q "oden-admin rapport" && ok "oden-admin: hjälp" || bad "oden-admin: hjälp"
printf '0\n' | "$oa" | grep -q "ODEN ADMIN" && ok "oden-admin: meny och avsluta" || bad "oden-admin: meny"
"$oa" versioner >/dev/null 2>&1 && "$oa" tjanster >/dev/null 2>&1 && ok "oden-admin: versioner och tjänster" || bad "oden-admin: delkommandon"
rc=0; "$oa" okandkommando >/dev/null 2>&1 || rc=$?; [[ $rc -eq 2 ]] && ok "oden-admin: okänt kommando ger 2" || bad "oden-admin: okänt kommando"
[[ -x overlay/etc/skel/Desktop/oden-admin.desktop ]] && ok "oden-admin: skrivbordsgenväg är körbar" || bad "oden-admin: skrivbordsgenväg saknar körrättighet"
"$oa" wifi >/dev/null 2>&1 && ok "oden-admin: wifi-felsökning" || bad "oden-admin: wifi"
ow=overlay/usr/local/bin/oden-wifi
bash -n "$ow" && "$ow" --help | grep -q "oden-wifi fil" && ok "oden-wifi: syntax och hjälp" || bad "oden-wifi: syntax/hjälp"
rc=0; "$ow" okand >/dev/null 2>&1 || rc=$?; [[ $rc -eq 2 ]] && ok "oden-wifi: okänt kommando ger 2" || bad "oden-wifi: okänt kommando"
grep -q "hidden yes" "$ow" && grep -q "d = dolt" "$ow" && ok "oden-wifi: dolda nät" || bad "oden-wifi: dolda nät"
for pk in wpasupplicant iw rfkill wireless-regdb; do grep -qx "$pk" config/config/package-lists/base.list.chroot || { bad "paketlista saknar $pk (apt-recommends är av)"; continue; }; done; ok "paketlista: wifi-paket (wpasupplicant m.fl.)"
grep -q '^NoDisplay=true' overlay/usr/local/share/applications/xfce4-session-logout.desktop && grep -q 'value="-logout"' config/config/hooks/normal/0100-oden.hook.chroot && grep -q 'xfce4-session-logout' config/config/hooks/normal/0100-oden.hook.chroot && ok "ingen Logga ut: menyval dolt, panelknapp och Ctrl+Alt+Delete borta" || bad "Logga ut är inte borttaget"
# oden-wifi mot en redan ansluten wifi får inte ändra något (landskod, radio, rfkill, skanning, anslutning): det kan koppla ned fungerande wifi
stub="$t/wifistub"; mkdir -p "$stub"
printf '#!/bin/bash\necho "sudo $*" >> "$LOG"; exec "$@"\n' > "$stub/sudo"
printf '#!/bin/bash\necho "rfkill $*" >> "$LOG"\n' > "$stub/rfkill"
printf '#!/bin/bash\necho "iw $*" >> "$LOG"\ncase "$*" in "reg get") echo "country 00: DFS-UNSET" ;; dev) printf "phy#0\\n\\tInterface wlan0\\n" ;; esac\n' > "$stub/iw"
cat > "$stub/nmcli" <<'STUB'
#!/bin/bash
echo "nmcli $*" >> "$LOG"
case "$*" in
 "-t -f DEVICE,TYPE,STATE device") echo "wlan0:wifi:connected" ;;
 "-t -f DEVICE,TYPE,STATE,CONNECTION device") echo "wlan0:wifi:connected:HemmaNat" ;;
 "-t -f ACTIVE,SSID device wifi list --rescan no") echo "yes:HemmaNat" ;;
 "radio wifi") echo disabled ;;
esac
STUB
chmod +x "$stub"/*; : > "$t/wifi.log"
printf 'n\n' | LOG="$t/wifi.log" PATH="$stub:$PATH" "$ow" >/dev/null 2>&1; LOG="$t/wifi.log" PATH="$stub:$PATH" "$ow" prep >/dev/null 2>&1 </dev/null
! grep -E 'rfkill unblock|reg set|wifi rescan|wifi connect|radio wifi on' "$t/wifi.log" >/dev/null && grep -q 'ACTIVE,SSID' "$t/wifi.log" && ok "oden-wifi: rör inte en ansluten wifi" || bad "oden-wifi: ändrar en ansluten wifi ($(grep -E 'rfkill unblock|reg set|wifi rescan|wifi connect|radio wifi on' "$t/wifi.log" | tr '\n' ';'))"
# oden-lock: bara krypteringslösenordet öppnar när lagringen finns; "live" (ingen kontroll här) bara när den saknas
ol=overlay/usr/local/bin/oden-lock; ls="$t/lockstub"; mkdir -p "$ls"
printf '#!/bin/bash\n[[ "$1" == -n ]] && shift\nexec "$@"\n' > "$ls/sudo"
printf '#!/bin/sh\necho /dev/fake\n' > "$ls/oden-persist-dev"
cat > "$ls/cryptsetup" <<'STUB'
#!/bin/bash
[ -f "$LUKSFLAG" ] || exit 1
case "$1" in isLuks) exit 0 ;; open) read -r -d '' k; [ "$k" = "gott losen" ] ;; esac
STUB
chmod +x "$ls"/*; export LUKSFLAG="$t/hasluks"; rm -f "$LUKSFLAG"
lk() { PATH="$ls:$PATH" "$ol" "$@"; }
bash -n "$ol" && lk --help | grep -q "krypteringslösenordet" && ok "oden-lock: syntax och hjälp" || bad "oden-lock: syntax/hjälp"
lk pam-unconfigured && ! printf 'gott losen\0' | lk pam-check && ok "oden-lock: utan krypterad lagring: ingen kontroll, live får gälla" || bad "oden-lock: utan lagring"
touch "$LUKSFLAG"
! lk pam-unconfigured && printf 'gott losen\0' | lk pam-check && ! printf 'live\0' | lk pam-check && ! printf '\0' | lk pam-check && ok "oden-lock: med krypterad lagring: bara lösenfrasen öppnar" || bad "oden-lock: med lagring"
rc=0; lk okand >/dev/null 2>&1 || rc=$?; [[ $rc -eq 2 ]] && ok "oden-lock: okänt kommando ger 2" || bad "oden-lock: okänt kommando"
# oden-hidpi: valet från oden-scale minns; 78oden-desktop: nya genvägar kommer, borttagna återuppstår inte
hs="$t/hidpi"; mkdir -p "$hs"; export ODEN_SCALEFILE="$hs/scale"
overlay/usr/local/bin/oden-hidpi save 1; [[ "$(ODEN_CMDLINE=/dev/null overlay/usr/local/bin/oden-hidpi scale)" == 1 ]] && overlay/usr/local/bin/oden-hidpi save 2 && [[ "$(ODEN_CMDLINE=/dev/null overlay/usr/local/bin/oden-hidpi scale)" == 2 ]] && overlay/usr/local/bin/oden-hidpi save auto && [[ ! -e "$hs/scale" ]] && ok "oden-hidpi: sparat skalval kvarstår, auto tar bort det" || bad "oden-hidpi: save"
unset ODEN_SCALEFILE
dk="$t/deskhome"; sk="$t/deskskel"; mkdir -p "$dk/Desktop" "$sk/Desktop"; echo a > "$sk/Desktop/a.desktop"; echo b > "$sk/Desktop/b.desktop"; echo gammal > "$dk/Desktop/a.desktop"
sed "s#/etc/skel#$sk#g" overlay/etc/X11/Xsession.d/78oden-desktop > "$t/78d"
HOME="$dk" sh "$t/78d"; [[ "$(cat "$dk/Desktop/a.desktop")" == gammal && -e "$dk/Desktop/b.desktop" ]] || bad "78oden-desktop: första körning"
rm "$dk/Desktop/b.desktop"; echo c > "$sk/Desktop/c.desktop"; HOME="$dk" sh "$t/78d"
[[ ! -e "$dk/Desktop/b.desktop" && -e "$dk/Desktop/c.desktop" ]] && ok "78oden-desktop: ny genväg läggs till, borttagen återkommer inte" || bad "78oden-desktop: ny/borttagen"
# oden-nm-persist: wifi-nät sparas på lagringen och finns kvar efter omstart (ny RAM-mapp), skrivs aldrig över
nm="$t/nm"; mkdir -p "$nm/src" "$nm/dst"; echo ssid1 > "$nm/dst/a.nmconnection"; echo gammal > "$nm/dst/b.nmconnection"; echo sparad > "$nm/src/b.nmconnection"
ODEN_NM_SRC="$nm/src" ODEN_NM_DST="$nm/dst" ODEN_NM_NOMOUNT=1 overlay/usr/local/bin/oden-nm-persist
[[ "$(cat "$nm/src/a.nmconnection")" == ssid1 && "$(cat "$nm/src/b.nmconnection")" == sparad && "$(stat -c %a "$nm/src")" == 700 ]] && ok "oden-nm-persist: kopierar nät, skriver inte över sparat, mappen är privat" || bad "oden-nm-persist"
grep -q 'oden-nm-persist.service' config/config/hooks/normal/0100-oden.hook.chroot && grep -q 'Before=NetworkManager' overlay/etc/systemd/system/oden-nm-persist.service && grep -q '^librsvg2-common' config/config/package-lists/base.list.chroot && ok "oden-nm-persist: tjänst före NetworkManager, påslagen; SVG-läsare i paketlistan" || bad "oden-nm-persist: tjänst/paket"
for i in wifi lock admin terminal wipe scale; do [[ -s overlay/usr/share/icons/hicolor/scalable/apps/oden-$i.svg ]] && python3 -c "import sys,xml.dom.minidom as m;m.parse(sys.argv[1])" overlay/usr/share/icons/hicolor/scalable/apps/oden-$i.svg || bad "ikon oden-$i.svg"; done; ok "ikoner: SVG giltiga"
# varje skrivbordsgenväg är körbar, har en ikon som finns och pekar på ett program som finns
for f in overlay/etc/skel/Desktop/*.desktop; do ic=$(sed -n 's/^Icon=//p' "$f"); [[ -x "$f" ]] || bad "genväg ej körbar: $f"; case "$ic" in oden) i=overlay/usr/share/icons/hicolor/256x256/apps/oden.png;; /*) i=;; *) i=overlay/usr/share/icons/hicolor/scalable/apps/$ic.svg;; esac; [[ -z "$i" || -s "$i" || "$ic" == utilities-terminal ]] || bad "ikon saknas för $f ($ic)"; done; ok "skrivbordsgenvägar: körbara, ikoner finns"
# oden-admin skrivare: lägga till via IP (drivrutinslöst), drivrutinssökning som reserv, USB, standardskrivare, ta bort
ps="$t/prstub"; mkdir -p "$ps"; PL="$t/pr.log"; : > "$PL"; export PL
printf '#!/bin/bash\nexec "$@"\n' > "$ps/sudo"
cat > "$ps/lpadmin" <<'STUB'
#!/bin/bash
echo "lpadmin $*" >> "$PL"
if [[ "$*" == *"-m everywhere"* && -n "${NOEVERY:-}" ]]; then exit 1; fi
exit 0
STUB
printf '#!/bin/bash\ncase "$1" in -v) echo "network ipp"; echo "direct usb://HP/LaserJet?serial=1";; -m) echo "drv:///foo.ppd Brother HL-1110"; echo "everywhere IPP Everywhere";; esac\n' > "$ps/lpinfo"
printf '#!/bin/bash\n[[ "$1" == -e ]] && { echo kontoret; echo hemma; exit 0; }\necho "lpstat $*"\n' > "$ps/lpstat"
printf '#!/bin/bash\necho "lp $*" >> "$PL"\n' > "$ps/lp"
printf '#!/bin/bash\necho "cancel $*" >> "$PL"\n' > "$ps/cancel"
chmod +x "$ps"/*
pa() { PATH="$ps:$PATH" "$oa"; }
printf '8\n2\n192.168.1.50\nkontoret\n\n0\n0\n' | pa >/dev/null 2>&1; grep -q 'lpadmin -p kontoret -E -v ipp://192.168.1.50/ipp/print -m everywhere' "$PL" && ok "oden-admin skrivare: lägg till via IP (drivrutinslöst)" || bad "oden-admin skrivare: IP ($(cat "$PL"))"
: > "$PL"; printf '8\n2\n10.0.0.9\nbrother\nbrother\n1\n\n0\n0\n' | NOEVERY=1 pa >/dev/null 2>&1; grep -q 'lpadmin -p brother -E -v ipp://10.0.0.9/ipp/print -m drv:///foo.ppd' "$PL" && ok "oden-admin skrivare: drivrutinssökning när drivrutinslöst saknas" || bad "oden-admin skrivare: drivrutinssökning ($(cat "$PL"))"
: > "$PL"; printf '8\n3\n1\nusbskr\n\n0\n0\n' | pa >/dev/null 2>&1; grep -q 'lpadmin -p usbskr -E -v usb://HP/LaserJet?serial=1 -m everywhere' "$PL" && ok "oden-admin skrivare: lägg till USB-skrivare" || bad "oden-admin skrivare: USB ($(cat "$PL"))"
: > "$PL"; printf '8\n4\n2\n\n5\n1\n\n7\n1\nj\n\n0\n0\n' | pa >/dev/null 2>&1; grep -q 'lpadmin -d hemma' "$PL" && grep -q 'lp -d kontoret' "$PL" && grep -q 'lpadmin -x kontoret' "$PL" && ok "oden-admin skrivare: standard, testsida, ta bort" || bad "oden-admin skrivare: hantera ($(cat "$PL"))"
PATH="$ps:$PATH" "$oa" skrivare >/dev/null 2>&1 && "$oa" hjalp | grep -q 'oden-admin skrivare' && ok "oden-admin skrivare: delkommando och hjälp" || bad "oden-admin skrivare: delkommando"
# Skrivare: paket, tjänster (cups på, browsed/avahi kvar av), sparade skrivare och lpadmin
for pk in cups cups-filters system-config-printer printer-driver-gutenprint; do grep -qx "$pk" config/config/package-lists/base.list.chroot || bad "skrivare: paket $pk saknas"; done
h=config/config/hooks/normal/0100-oden.hook.chroot
grep -q 'enable cups.socket' $h && grep -q 'oden-cups-persist.service' $h && grep -q 'cups-browsed.service' $h && ! grep -E '^ *avahi-daemon.service cups\.service' $h >/dev/null && ! grep -q 'cups.service cups-browsed' $h && grep -q 'lpadmin' overlay/etc/live/config.conf.d/oden.conf && ok "skrivare: cups påslagen (browsed/avahi av), lpadmin, sparas" || bad "skrivare: hook/grupper"
cp="$t/cups"; mkdir -p "$cp/src" "$cp/dst/ppd"; echo 'cupsd' > "$cp/dst/cupsd.conf"; echo x > "$cp/dst/ppd/a.ppd"; echo y > "$cp/dst/.hidden"; echo '<P>sparad' > "$cp/src/printers.conf"
ODEN_NM_SRC="$cp/src" ODEN_NM_DST="$cp/dst" ODEN_NM_NOMOUNT=1 overlay/usr/local/bin/oden-nm-persist cups
[[ -f "$cp/src/ppd/a.ppd" && -f "$cp/src/cupsd.conf" && -f "$cp/src/.hidden" && "$(cat "$cp/src/printers.conf")" == '<P>sparad' ]] && ok "oden-nm-persist cups: kopierar /etc/cups (även ppd/ och dolda filer), skriver inte över" || bad "oden-nm-persist cups"
[[ -x overlay/etc/skel/Desktop/oden-printer.desktop && -s overlay/usr/share/icons/hicolor/scalable/apps/oden-printer.svg ]] && ok "skrivare: skrivbordsgenväg och ikon" || bad "skrivare: genväg/ikon"
# oden-lock: "Lås nu" slår på /lock/enabled (annars gör --lock ingenting); tid väljer minuter
XL="$t/xfconf.log"; : > "$XL"
printf '#!/bin/bash\nwhile [[ $# -gt 0 ]]; do case "$1" in -p) p=$2; shift;; -s) v=$2; shift;; esac; shift; done\n[[ -n "${v:-}" ]] && echo "$p=$v" >> "$XL"\nexit 1\n' > "$ls/xfconf-query"
printf '#!/bin/bash\necho "cmd $*" >> "$XL"\n' > "$ls/xfce4-screensaver-command"; chmod +x "$ls"/*
export XL; touch "$LUKSFLAG"
lk lock >/dev/null 2>&1 || true; grep -q '^/lock/enabled=true' "$XL" && grep -q '^/lock/saver-activation/enabled=false' "$XL" && grep -q 'cmd --lock' "$XL" && ok "oden-lock: lås nu slår på /lock/enabled utan inaktivitetslås" || bad "oden-lock: lås nu"
: > "$XL"; lk tid 7 >/dev/null 2>&1 || true; grep -q '^/saver/idle-activation/delay=7' "$XL" && grep -q '^/lock/saver-activation/enabled=true' "$XL" && ok "oden-lock: tid 7 sätter 7 minuter och slår på lås" || bad "oden-lock: tid"
rc=0; lk tid 0 >/dev/null 2>&1 || rc=$?; [[ $rc -eq 2 ]] && ok "oden-lock: ogiltig tid avvisas" || bad "oden-lock: ogiltig tid"
rm -f "$LUKSFLAG"
[[ -x overlay/etc/skel/Desktop/oden-lock.desktop ]] && grep -q 'oden-lock menu' overlay/etc/skel/Desktop/oden-lock.desktop && ok "oden-lock: skrivbordsgenväg" || bad "oden-lock: skrivbordsgenväg"
grep -q 'oden-lock pam-check' overlay/etc/pam.d/xfce4-screensaver && grep -q '^xfce4-screensaver$' config/config/package-lists/base.list.chroot && grep -q 'value="+lock-screen"' config/config/hooks/normal/0100-oden.hook.chroot && grep -q 'oden-lock lock' config/config/hooks/normal/0100-oden.hook.chroot && ok "oden-lock: PAM, paket, panelknapp och LockCommand på plats" || bad "oden-lock: inkoppling saknas"
# oden-usb-watch: stänger av (skriver o till sysrq) när startdisken försvinner, men inte vid en kort hickup; riktiga /proc rörs inte
uw=overlay/usr/local/bin/oden-usb-watch; sb="$t/sysblock"; mkdir -p "$sb/sdx"
uwrun() { ODEN_BOOTDISK=sdx ODEN_SYSBLOCK="$sb" ODEN_SYSRQ="$t/sysrq" ODEN_SYSRQ_ENABLE="$t/sysrqen" ODEN_FIFO="$t/uwfifo" ODEN_USBWATCH_GRACE=3 ODEN_USBWATCH_TEST=1 "$uw" >/dev/null 2>&1 & uwpid=$!; }
bash -n "$uw" && ok "oden-usb-watch: syntax" || bad "oden-usb-watch: syntax"
: > "$t/sysrq"; uwrun; sleep 1.2; [[ ! -s "$t/sysrq" && "$(cat "$t/sysrqen")" == 1 ]] && ok "oden-usb-watch: tyst och sysrq påslaget medan stickan finns" || bad "oden-usb-watch: agerar utan anledning"
rmdir "$sb/sdx"; sleep 0.5; mkdir "$sb/sdx"; sleep 2; [[ ! -s "$t/sysrq" ]] && ok "oden-usb-watch: kort hickup stänger inte av" || bad "oden-usb-watch: hickup gav avstängning"
rmdir "$sb/sdx"; sleep 3; [[ "$(cat "$t/sysrq")" == o ]] && ok "oden-usb-watch: uttag ger sysrq o" || bad "oden-usb-watch: uttag gav inte avstängning ($(cat "$t/sysrq"))"
kill "$uwpid" 2>/dev/null || true; wait "$uwpid" 2>/dev/null || true
rc=0; ODEN_BOOTDISK=saknas ODEN_SYSBLOCK="$sb" ODEN_FIFO="$t/uwfifo" "$uw" >/dev/null 2>&1 || rc=$?; [[ $rc -eq 1 ]] && ok "oden-usb-watch: avbryter om disken inte finns" || bad "oden-usb-watch: saknad disk"
# oden-ramcache: tar med kataloger inom gränsen, hoppar över vid för lite RAM
rc_out=$(ODEN_RAMCACHE_DRYRUN=1 ODEN_RAMCACHE_MAX=$((4*1024**3)) overlay/usr/local/bin/oden-ramcache 2>&1); echo "$rc_out" | grep -q 'totalt högst' && ok "oden-ramcache: väljer kataloger inom gränsen" || bad "oden-ramcache: urval"
ODEN_RAMCACHE_MAX=1000 overlay/usr/local/bin/oden-ramcache 2>&1 | grep -q 'för lite RAM' && ok "oden-ramcache: hoppar över vid för liten gräns" || bad "oden-ramcache: liten gräns"
grep -q oden-usb-watch config/config/hooks/normal/0100-oden.hook.chroot && grep -q oden-ramcache config/config/hooks/normal/0100-oden.hook.chroot && grep -qx vmtouch config/config/package-lists/base.list.chroot && ok "oden-usb-watch/ramcache: tjänster aktiverade och vmtouch i paketlistan" || bad "oden-usb-watch/ramcache: inkoppling saknas"
"$ow" status >/dev/null 2>&1 && ok "oden-wifi: status" || bad "oden-wifi: status"
[[ -x overlay/etc/skel/Desktop/oden-wifi.desktop && -f overlay/etc/systemd/system/oden-wifi-prep.service ]] && grep -q oden-wifi-prep config/config/hooks/normal/0100-oden.hook.chroot && ok "oden-wifi: genväg och uppstartstjänst" || bad "oden-wifi: genväg/tjänst"
(HOME="$t" "$oa" rapport >/dev/null 2>&1; ls "$t"/oden-felsok-*.txt >/dev/null 2>&1) && ok "oden-admin: rapport skrivs" || bad "oden-admin: rapport"

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
