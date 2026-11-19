#!/usr/bin/env bash
# Skriver bild (p1+p2), skapar p3 (assets) och en tom p4 (krypteras vid första start).
#   make-stick.sh [--with-ai] <bild> <enhet>
set -euo pipefail
with_ai=0
[[ "${1:-}" == "--with-ai" ]] && { with_ai=1; shift; }
img="${1:?bild saknas}"; dev="${2:?enhet saknas (t.ex. /dev/sdX)}"

[[ -b "$dev" ]] || { echo "$dev är ingen blockenhet" >&2; exit 1; }
[[ "$(lsblk -no RM "$dev" | head -1 | tr -d ' ')" == 1 ]] || { echo "$dev är inte en flyttbar enhet; avbryter" >&2; exit 1; }
lsblk "$dev"
read -rp "ALLT på $dev raderas. Skriv 'ja' för att fortsätta: " ok
[[ "$ok" == ja ]] || exit 1

echo "TODO: skriv $img, skapa p3 (ext4, oden-assets) och p4 (tom); with_ai=$with_ai" >&2
exit 2
