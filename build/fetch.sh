#!/usr/bin/env bash
# Hämtar alla artefakter i artifacts.lock till build/cache/. Enda steget som använder nät.
#   fetch.sh            hämta och verifiera allt
#   fetch.sh --pin NAMN skriv ut SHA256 för NAMN (efter hämtning) så att den kan föras in i lock-filen
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p cache

pin=""
[[ "${1:-}" == "--pin" ]] && pin="${2:?namn saknas}"

while read -r name url sha _; do
  [[ -z "${name:-}" || "$name" == \#* ]] && continue
  [[ -n "$pin" && "$name" != "$pin" ]] && continue
  if [[ "$url" == PENDING_URL ]]; then
    echo "FEL: $name saknar URL i artifacts.lock" >&2; exit 1
  fi
  out="cache/$name"
  if [[ ! -f "$out" ]]; then
    echo "Hämtar $name"
    curl -fL --retry 3 -o "$out.part" "$url"
    mv "$out.part" "$out"
  fi
  actual=$(sha256sum "$out" | cut -d' ' -f1)
  if [[ -n "$pin" ]]; then
    echo "$name  $actual"
  elif [[ "$sha" == PENDING ]]; then
    echo "FEL: $name är inte låst (kör: fetch.sh --pin $name)" >&2; exit 1
  elif [[ "$actual" != "$sha" ]]; then
    echo "FEL: checksumma avviker för $name" >&2; exit 1
  fi
done < artifacts.lock
echo "OK"
