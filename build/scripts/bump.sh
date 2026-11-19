#!/usr/bin/env bash
# Uppgraderar (eller låser om) en artefakt i artifacts.lock från GitHub-releaser.
#   bump.sh --list                   visa artefakter i låset
#   bump.sh <namn> [version|latest]  t.ex. bump.sh go-pmtiles 1.32.0   eller   bump.sh ollama latest
# Hämtar URL och SHA256 (GitHubs digest, annars nedladdning) och skriver artefaktens rad i artifacts.lock med
# versionsinfo som kommentar efter checksumman. Ändrar inget annat; granska med `git diff` och bygg sedan.
# Källor (repo, taggmall, asset-mönster) står i sources.conf. oden-linux byggs av build-oden.sh och bumpas inte
# direkt: bumpa oden-source, jre-x64 eller signal-cli, så byggs den om.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == --list ]]; then grep -v '^#' artifacts.lock | awk 'NF {print $1, $2}'; exit 0; fi
name="${1:?namn saknas (se --list)}"; ver="${2:-latest}"
read -r _ repo tagtpl rx < <(awk -v n="$name" '$1==n' sources.conf) || true
[[ -n "${repo:-}" ]] || { echo "FEL: $name finns inte i sources.conf" >&2; exit 1; }
command -v gh >/dev/null || { echo "FEL: gh (GitHub CLI) krävs" >&2; exit 1; }

if [[ "$ver" == latest ]]; then api="repos/$repo/releases/latest"
else api="repos/$repo/releases/tags/${tagtpl//\{v\}/$ver}"; fi
rel=$(gh api "$api")

# url, sha (eller "-" om GitHub saknar digest), tagg
read -r url sha tag < <(REL="$rel" python3 - "$repo" "$rx" <<'PY'
import json, os, re, sys
repo, rx = sys.argv[1:3]
rel = json.loads(os.environ["REL"])
tag = rel["tag_name"]
if rx == "-":
    print(f"https://github.com/{repo}/archive/refs/tags/{tag}.tar.gz - {tag}")
else:
    m = [a for a in rel["assets"] if re.search(rx, a["name"])]
    if len(m) != 1:
        sys.exit(f"FEL: {len(m)} asset matchar {rx!r} i {tag}: {[a['name'] for a in rel['assets']]}")
    d = (m[0].get("digest") or "").removeprefix("sha256:") or "-"
    print(m[0]["browser_download_url"], d, tag)
PY
)
info="$tag"
if [[ "$rx" == - ]]; then info="$tag commit $(gh api "repos/$repo/commits/$tag" --jq .sha)"; fi

# Utan digest från GitHub: hämta och räkna själv.
if [[ "$sha" == - ]]; then
  mkdir -p cache; tmp="cache/$name.bump"
  curl -fsSL --retry 3 -o "$tmp" "$url"
  sha=$(sha256sum "$tmp" | cut -d' ' -f1); rm -f "$tmp"
fi

old=$(awk -v n="$name" '$1==n' artifacts.lock)
new=$(printf '%-19s %s  %s  # %s' "$name" "$url" "$sha" "$info")
[[ -n "$old" ]] || { echo "FEL: $name saknas i artifacts.lock" >&2; exit 1; }
if [[ "$old" == "$new" ]]; then echo "Oförändrat: $name ($info)"; exit 0; fi

NAME="$name" NEW="$new" python3 - <<'PY'
import os
n, new = os.environ["NAME"], os.environ["NEW"]
out = []
for l in open("artifacts.lock"):
    out.append(new + "\n" if l.split(" ")[0] == n else l)
open("artifacts.lock", "w").write("".join(out))
PY

# Ändrades själva innehållet (inte bara kommentaren) är gammal nedladdning ogiltig, och byggda artefakter
# som beror på denna måste byggas om.
if [[ "$(awk '{print $2, $3}' <<<"$old")" != "$url $sha" ]]; then
  rm -f "cache/$name"
  case "$name" in oden-source|jre-x64|signal-cli) rm -f cache/oden-linux cache/oden-linux.pip-freeze.txt ;; esac
fi
echo "Uppdaterad: $name -> $info"
echo "Nästa: git diff build/artifacts.lock, sedan ./build/build.sh"
