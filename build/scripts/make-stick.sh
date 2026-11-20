#!/usr/bin/env bash
# Skriver bild (p1+p2), skapar p3 (assets) och en tom p4 (krypteras vid första start, steg 03).
#   make-stick.sh [--with-ai] <bild> <enhet>
# Assets hämtas från $ODEN_ASSETS (standard build/cache/assets):
#   maps/    kartfiler (krävs)         -> p3:/maps    (ska monteras som /srv/oden-assets/maps)
#   ollama/  modeller (med --with-ai)  -> p3:/ollama
# Layout: p1 (ISO-data) + p2 (EFI) från bilden, p3 ext4 "oden-assets", p4 resten med GPT-namn "persistence" (live-boot
# hittar den krypterade partitionen via det namnet) och nollad header.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[[ $EUID -eq 0 ]] || exec sudo env ODEN_ASSETS="${ODEN_ASSETS:-}" "$0" "$@"

with_ai=0
[[ "${1:-}" == "--with-ai" ]] && { with_ai=1; shift; }
img="${1:?bild saknas}"; dev="${2:?enhet saknas (t.ex. /dev/sdX)}"
assets="${ODEN_ASSETS:-$here/../cache/assets}"
MIN_BYTES=60000000000   # "64 GB"-stickor är oftast ca 60-63 GB

for t in sgdisk sfdisk wipefs mkfs.ext4 partprobe udevadm lsblk blkid; do
  command -v "$t" >/dev/null || { echo "Verktyget $t saknas (apt install gdisk fdisk e2fsprogs parted)" >&2; exit 1; }
done

# --- Förkontroller: inget skrivs förrän allt här är godkänt ---
[[ -f "$img" ]] || { echo "Bilden $img finns inte" >&2; exit 1; }
[[ -b "$dev" ]] || { echo "$dev är ingen blockenhet" >&2; exit 1; }
[[ "$(lsblk -dno TYPE "$dev")" == disk ]] || { echo "$dev är inte en hel disk (ange t.ex. /dev/sdX, inte /dev/sdX1)" >&2; exit 1; }
[[ "$(lsblk -dno RM "$dev" | tr -d ' ')" == 1 ]] || { echo "$dev är inte en flyttbar enhet; avbryter" >&2; exit 1; }
dev_bytes=$(blockdev --getsize64 "$dev")
(( dev_bytes >= MIN_BYTES )) || { echo "$dev är för liten ($((dev_bytes / 1000000000)) GB, kräver >= 60 GB)" >&2; exit 1; }

# Bilden ska ha exakt p1 (ISO-data) + p2 (EFI); annars stämmer inte numreringen p3/p4.
nparts=$(sfdisk -d "$img" | grep -c ': start=' || true)
(( nparts == 2 )) || { echo "Bilden har $nparts partitioner, förväntade 2 (ISO + EFI). Justera live-build-konfigen eller skriptet." >&2; exit 1; }

[[ -d "$assets/maps" && -n "$(ls -A "$assets/maps")" ]] || { echo "Kartor saknas i $assets/maps" >&2; exit 1; }
if (( with_ai )); then
  [[ -d "$assets/ollama" && -n "$(ls -A "$assets/ollama")" ]] || { echo "Modeller saknas i $assets/ollama (krävs med --with-ai)" >&2; exit 1; }
fi

# p3-storlek: innehållet + 5 % + 256 MiB, avrundat till hela MiB.
need=$(du -sb "$assets/maps" | cut -f1)
if (( with_ai )); then need=$(( need + $(du -sb "$assets/ollama" | cut -f1) )); fi
p3_mib=$(( (need + need / 20) / 1048576 + 256 ))
img_bytes=$(stat -c %s "$img")
(( img_bytes + (p3_mib + 64) * 1048576 < dev_bytes )) || { echo "Bild + assets ryms inte på $dev" >&2; exit 1; }

lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS "$dev"
echo "Skriver $(basename "$img") ($((img_bytes / 1048576)) MiB), p3 $p3_mib MiB (ai=$with_ai), p4 = resten."
read -rp "ALLT på $dev raderas. Skriv 'ja' för att fortsätta: " ok
[[ "$ok" == ja ]] || exit 1

# --- Skriv ---
while read -r mp; do [[ -n "$mp" ]] && umount "$mp"; done < <(lsblk -nrpo MOUNTPOINT "$dev" | sort -r)

mnt=""
cleanup() {
  if [[ -n "$mnt" ]]; then mountpoint -q "$mnt" && umount "$mnt"; rmdir "$mnt"; fi
}
trap 'cleanup 2>/dev/null || true' EXIT

sgdisk --zap-all "$dev" >/dev/null 2>&1 || true   # gammal GPT (även sikthuvudet sist på disken) och MBR
wipefs -a "$dev" >/dev/null
dd if="$img" of="$dev" bs=4M conv=fsync status=progress

# GPT krävs (partitionsnamn). Flytta sikthuvudet till diskens slut, eller konvertera MBR -> GPT.
partprobe "$dev"; udevadm settle
if [[ "$(blkid -o value -s PTTYPE "$dev" || true)" == gpt ]]; then
  sgdisk -e "$dev" >/dev/null
else
  sgdisk -g "$dev" >/dev/null
fi
sgdisk -t 2:EF00 "$dev" >/dev/null                 # p2 är EFI-partitionen (p1 är ISO-data)
sgdisk -n "3:0:+${p3_mib}M" -t 3:8300 -c 3:oden-assets \
       -n 4:0:0             -t 4:8309 -c 4:persistence "$dev" >/dev/null
partprobe "$dev"; udevadm settle

part_of() { lsblk -nrpo NAME,PARTLABEL "$dev" | awk -v l="$1" '$2==l {print $1}'; }
p3=$(part_of oden-assets); p4=$(part_of persistence)
[[ -b "$p3" && -b "$p4" ]] || { echo "Hittade inte nya p3/p4 på $dev" >&2; exit 1; }

# p4 ska vara helt tom: en gammal LUKS-header från en tidigare stick på samma plats skulle få
# oden-firstboot att tro att den redan är formaterad. LUKS2-header är upp till 16 MiB.
wipefs -a "$p4" >/dev/null
dd if=/dev/zero of="$p4" bs=1M count=16 conv=fsync status=none

mkfs.ext4 -q -F -m 0 -L oden-assets "$p3"
mnt=$(mktemp -d)
mount "$p3" "$mnt"
cp -a "$assets/maps" "$mnt/maps"
if (( with_ai )); then cp -a "$assets/ollama" "$mnt/ollama"; fi
sync
umount "$mnt"

echo "Klart. p1 ISO-data, p2 EFI, p3 assets ($p3), p4 $p4 (krypteras vid första start)."
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL "$dev"
