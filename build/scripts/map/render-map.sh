#!/usr/bin/env bash
# Renderar rasterkartan ODEN använder (Sverige, PMTiles) ur Protomaps vektorfil. Körs en gång, på valfri maskin med Docker;
# resultatet (sverige.pmtiles) laddas upp och läggs i ODEN-bygget. Se docs/KARTRENDERING.md.
#   build/scripts/map/render-map.sh                      # z0-14, hela Sverige
#   ZMAX=12 WORK=/data/karta build/scripts/map/render-map.sh
# Kan avbrytas (Ctrl+C) och köras om: nedladdning, stil och redan renderade rutor återanvänds.
# Miljövariabler: ZMAX (14), ZMIN (0), WORKERS (antal kärnor), WORK (./map-work), PORT (18081), BOUNDS (Sverige).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
ZMAX="${ZMAX:-14}"; ZMIN="${ZMIN:-0}"; WORKERS="${WORKERS:-$(nproc)}"; WORK="$(mkdir -p "${WORK:-$PWD/map-work}" && cd "${WORK:-$PWD/map-work}" && pwd)"
PORT="${PORT:-18081}"; BOUNDS="${BOUNDS:-10.54,55.20,24.17,69.07}"

# Allt som påverkar resultatet är låst här (versionerna är de som provats):
SRC_URL="https://kartverktyget.s3.eu-central-003.backblazeb2.com/sweden-osm.pmtiles"
SRC_SHA="59fe0b51666c9ab95a03fce87bb5e8aced22a4edcba25560dfb176884bf3027a"
SRC_BYTES=4092223980
TILESERVER_IMAGE="maptiler/tileserver-gl:v5.7.0"
NODE_IMAGE="node:22-slim"
BASEMAPS_VERSION="5.7.2"                                      # npm: @protomaps/basemaps (stilen)
ASSETS_REPO="https://github.com/protomaps/basemaps-assets"
ASSETS_COMMIT="028c18f713baecad011301ff7a69acc39bcc2ae7"        # typsnitt och sprites
GOPM_URL="https://github.com/protomaps/go-pmtiles/releases/download/v1.31.2/go-pmtiles_1.31.2_Linux_x86_64.tar.gz"
GOPM_SHA="3ed7dbf4ec2e6dfe5e25b6f70d1ffc932729f93c86db353bf514dd71010a312f"
NAME="odenmap-render-$$"

say() { echo "[$(date +%H:%M:%S)] $*"; }
for t in docker curl git python3 sha256sum tar; do command -v "$t" >/dev/null || { echo "FEL: $t saknas" >&2; exit 1; }; done
docker info >/dev/null 2>&1 || { echo "FEL: docker går inte att nå" >&2; exit 1; }

# Diskutrymme: källa 4,1 GB + MBTiles + PMTiles (z14 ca 3 GB var, mätt och extrapolerat)
avail_gb=$(( $(df -Pk "$WORK" | awk 'NR==2 {print $4}') / 1048576 ))
need_gb=$(( ZMAX >= 14 ? 15 : 10 ))
(( avail_gb >= need_gb )) || { echo "FEL: $avail_gb GB ledigt i $WORK, räknar med minst $need_gb GB för ZMAX=$ZMAX" >&2; exit 1; }
say "arbetsmapp $WORK, z$ZMIN-$ZMAX, $WORKERS parallella, $avail_gb GB ledigt"

# 1. Källfilen (återupptar delvis nedladdning)
src="$WORK/sweden-osm.pmtiles"
if [[ ! -f "$src" ]] || [[ "$(stat -c %s "$src")" != "$SRC_BYTES" ]]; then
  say "hämtar källfilen (4,1 GB)"; curl -fL --retry 5 -C - -o "$src" "$SRC_URL"
fi
[[ "$(stat -c %s "$src")" == "$SRC_BYTES" ]] || { echo "FEL: fel storlek på $src" >&2; exit 1; }
if [[ ! -f "$src.ok" ]]; then
  say "kontrollerar checksumma"; [[ "$(sha256sum "$src" | cut -d' ' -f1)" == "$SRC_SHA" ]] || { echo "FEL: checksumman för $src stämmer inte" >&2; exit 1; }
  touch "$src.ok"
fi

# 2. Stil, typsnitt och sprites -> $WORK/data (tileserver-gl:s rotkatalog)
data="$WORK/data"; mkdir -p "$data/styles" "$data/fonts" "$data/pmtiles"
if [[ ! -f "$data/styles/oden.json" ]]; then
  say "skapar stilen (Protomaps Basemap $BASEMAPS_VERSION, tema light, svenska namn)"
  mkdir -p "$WORK/style-build"; cp "$here/gen-style.mjs" "$WORK/style-build/"
  docker run --rm -v "$WORK/style-build":/w -v "$data/styles":/out -w /w -e MAP_LANG=sv "$NODE_IMAGE" \
    sh -c "npm i --silent --no-audit --no-fund @protomaps/basemaps@$BASEMAPS_VERSION && node gen-style.mjs && chown -R $(id -u):$(id -g) /out /w"
fi
if [[ ! -d "$WORK/assets/.git" ]]; then
  say "hämtar typsnitt och sprites"; git clone -q "$ASSETS_REPO" "$WORK/assets"
fi
git -C "$WORK/assets" checkout -q "$ASSETS_COMMIT"
cp -r "$WORK/assets/fonts/." "$data/fonts/"
for f in .json .png @2x.json @2x.png; do cp "$WORK/assets/sprites/v4/light$f" "$data/styles/sprite$f"; done
ln -sf "$src" "$data/pmtiles/sweden-osm.pmtiles"
cat > "$data/config.json" <<J
{
  "options": { "paths": { "root": "/data", "fonts": "fonts", "styles": "styles", "pmtiles": "pmtiles" },
               "formatQuality": { "webp": 85 }, "maxRendererPoolSizes": [$WORKERS, 1, 1] },
  "styles": { "oden": { "style": "oden.json" } },
  "data": { "sweden": { "pmtiles": "sweden-osm.pmtiles" } }
}
J

# 3. Tileserver (renderar rutor ur vektorfilen) och hämtning av alla rutor till MBTiles
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }; trap cleanup EXIT
say "startar tileserver-gl ($TILESERVER_IMAGE)"
docker run -d --name "$NAME" -p "127.0.0.1:$PORT:8080" -v "$data":/data:ro -v "$src":/data/pmtiles/sweden-osm.pmtiles:ro \
  "$TILESERVER_IMAGE" --config /data/config.json >/dev/null
for i in $(seq 1 60); do
  [[ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/styles/oden/0/0/0.webp")" == 200 ]] && break
  sleep 2; [[ $i -lt 60 ]] || { docker logs "$NAME" 2>&1 | tail -20; echo "FEL: tileservern kom aldrig upp" >&2; exit 1; }
done
mb="$WORK/sverige-z$ZMIN-$ZMAX.mbtiles"
say "renderar rutor till $mb"
python3 -I "$here/fetch-tiles.py" --url "http://127.0.0.1:$PORT/styles/oden" --out "$mb" --zmin "$ZMIN" --zmax "$ZMAX" \
  --workers "$WORKERS" --bounds "$BOUNDS"
cleanup; trap - EXIT

# 4. MBTiles -> PMTiles
pm="$WORK/pmtiles-bin"; mkdir -p "$pm"
if [[ ! -x "$pm/pmtiles" ]]; then
  curl -fL --retry 3 -o "$pm/g.tgz" "$GOPM_URL"; [[ "$(sha256sum "$pm/g.tgz" | cut -d' ' -f1)" == "$GOPM_SHA" ]] || { echo "FEL: go-pmtiles avviker" >&2; exit 1; }
  tar -xzf "$pm/g.tgz" -C "$pm" pmtiles
fi
out="$WORK/sverige.pmtiles"; rm -f "$out"
say "konverterar till PMTiles"
"$pm/pmtiles" convert "$mb" "$out"
"$pm/pmtiles" show "$out" | head -20
say "klart: $out"
echo "  storlek:  $(stat -c %s "$out") byte ($(du -h "$out" | cut -f1))"
echo "  sha256:   $(sha256sum "$out" | cut -d' ' -f1)"
echo "Nästa steg: ladda upp filen och sätt ODEN_MAPS_URL i .env (minimal) eller lägg den i \$ODEN_ASSETS/maps/ (karta). Se docs/KARTRENDERING.md."
