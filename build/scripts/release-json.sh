#!/usr/bin/env bash
# Skriver site/releases.json (till stdout) för ISO-filerna i build/out: variant, fil, url, storlek, SHA256.
#   release-json.sh <bas-url> [ut-katalog]     (url blir <bas-url>/<filnamn>; standard ut-katalog build/out)
# "published" = dagens datum, eller ODEN_PUBLISHED=ÅÅÅÅ-MM-DD.
# Ladda upp ISO-filerna på bas-url (S3, Drive, ...), kör skriptet, lägg resultatet i site/releases.json och committa.
set -euo pipefail
base="${1:?bas-url saknas}"; dir="${2:-$(cd "$(dirname "$0")/.." && pwd)/out}"
python3 -I - "$base" "$dir" <<'PY'
import datetime, glob, json, os, re, sys
base, d = sys.argv[1].rstrip("/"), sys.argv[2]
isos = []
for f in sorted(glob.glob(os.path.join(d, "oden-*-*.iso"))):
    name = os.path.basename(f)
    m = re.fullmatch(r"oden-(minimal|karta-ai|karta)-(.+)\.iso", name)
    if not m: continue
    sums = f + ".sha256"
    if not os.path.exists(sums):
        sys.exit(f"{name}: {name}.sha256 saknas")
    sha = open(sums).read().split()[0]
    if not re.fullmatch(r"[0-9a-f]{64}", sha):
        sys.exit(f"{name}: ogiltig kontrollsumma")
    isos.append({"variant": m.group(1), "version": m.group(2), "file": name,
                 "published": os.environ.get("ODEN_PUBLISHED") or datetime.date.today().isoformat(),
                 "url": f"{base}/{name}", "bytes": os.path.getsize(f), "sha256": sha})
if not isos:
    sys.exit("inga oden-<variant>-<version>.iso i " + d)
print(json.dumps({"isos": isos}, indent=2, ensure_ascii=False))
PY
