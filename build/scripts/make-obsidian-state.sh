#!/usr/bin/env bash
# Skapar Obsidians färdiga startläge i overlayn: valvet registrerat (obsidian.json) och community-plugins påslagna.
# Obsidian slår på plugins bara om localStorage har enable-plugin-<valv-id> = true (annars visas dialogen "Slå på
# community-plugins"). localStorage ligger i Chromiums LevelDB; här skrivs den nyckeln i förväg.
#   build/scripts/make-obsidian-state.sh     (kräver docker; resultatet är incheckat i overlay/etc/skel/.config/obsidian)
set -euo pipefail
cd "$(dirname "$0")/.."
ID=6f64656e76616c76          # valv-id: 16 hex-tecken (= "odenvalv"); samma id i obsidian.json och nyckeln
HOME_DIR=/home/oden          # användaren heter oden (username=oden i bootparametrarna)
dest=overlay/etc/skel/.config/obsidian
rm -rf "$dest/Local Storage"; mkdir -p "$dest/Local Storage"
cat > "$dest/obsidian.json" <<J
{
  "vaults": {
    "$ID": { "path": "$HOME_DIR/ODEN-valv", "ts": 1767225600000, "open": true }
  },
  "updateDisabled": true
}
J
docker run --rm -v "$PWD/$dest":/d -e ID="$ID" -e OWNER="$(id -u):$(id -g)" python:3.12-bookworm bash -euc '
  pip install -q plyvel 2>&1 | grep -v -i "notice\|warning" || true
  python - <<P
import os, plyvel
db = plyvel.DB("/d/Local Storage/leveldb", create_if_missing=True)
origin = b"app://obsidian.md"
# Chromiums format: VERSION, och nyckel "_<origin>\0" + kodbyte (0x01 = latin1) + namn; värde: kodbyte + text
db.put(b"VERSION", b"1")
db.put(b"_" + origin + b"\x00\x01enable-plugin-" + os.environ["ID"].encode(), b"\x01true")
db.close()
db = plyvel.DB("/d/Local Storage/leveldb")
print([ (k, v) for k, v in db ])
db.close()
P
  chown -R "$OWNER" /d
'
find "$dest" -type f | sort
