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

pp() { printf '%s' "$1" | ODEN_MINLEN=16 overlay/usr/local/bin/oden-passphrase-ok; }
pp "fyra vanliga ord pa rad" && ok "lösenfras: giltig godkänns" || bad "lösenfras: giltig godkänns"
pp "Hemligt lösenord 12345" && bad "lösenfras: å/ö avvisas" || ok "lösenfras: å/ö avvisas"
pp "tillrackligt-langt-men-bindestreck" && bad "lösenfras: symboler avvisas" || ok "lösenfras: symboler avvisas"
pp "kort fras" && bad "lösenfras: för kort avvisas" || ok "lösenfras: för kort avvisas"
pp "" && bad "lösenfras: tom avvisas" || ok "lösenfras: tom avvisas"

exit $fail
