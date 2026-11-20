#!/usr/bin/env python3
"""Hämtar rasterrutor från en tileserver-gl och skriver dem till MBTiles (deduplicerat; återupptar där det slutade).
  fetch-tiles.py --url http://127.0.0.1:18081/styles/oden --out sverige.mbtiles --zmin 0 --zmax 12 [--workers 6] [--bounds w,s,e,n]
Rutor som redan finns hämtas inte igen. Avbryt med Ctrl+C och kör om för att fortsätta."""
import argparse, hashlib, math, os, sqlite3, sys, threading, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

ap = argparse.ArgumentParser()
ap.add_argument("--url", required=True, help="bas-URL, t.ex. http://127.0.0.1:18081/styles/oden")
ap.add_argument("--out", required=True)
ap.add_argument("--zmin", type=int, default=0)
ap.add_argument("--zmax", type=int, required=True)
ap.add_argument("--bounds", default="10.54,55.20,24.17,69.07", help="väst,syd,öst,nord (Sverige)")
ap.add_argument("--workers", type=int, default=6)
ap.add_argument("--ext", default="webp")
a = ap.parse_args()
w, s, e, n = map(float, a.bounds.split(","))

def tx(lon, z): return int((lon + 180.0) / 360.0 * (1 << z))
def ty(lat, z):
    r = math.radians(lat)
    return int((1.0 - math.asinh(math.tan(r)) / math.pi) / 2.0 * (1 << z))

def tiles(z):
    x0, x1 = tx(w, z), min(tx(e, z), (1 << z) - 1)
    y0, y1 = ty(n, z), min(ty(s, z), (1 << z) - 1)
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            yield z, x, y

db = sqlite3.connect(a.out)
db.executescript("""
PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;
CREATE TABLE IF NOT EXISTS metadata (name TEXT, value TEXT);
CREATE TABLE IF NOT EXISTS map (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_id TEXT);
CREATE TABLE IF NOT EXISTS images (tile_id TEXT PRIMARY KEY, tile_data BLOB);
CREATE UNIQUE INDEX IF NOT EXISTS map_index ON map (zoom_level, tile_column, tile_row);
CREATE VIEW IF NOT EXISTS tiles AS SELECT map.zoom_level AS zoom_level, map.tile_column AS tile_column, map.tile_row AS tile_row, images.tile_data AS tile_data FROM map JOIN images ON images.tile_id = map.tile_id;
""")
meta = {"name": "ODEN Sverige", "format": a.ext, "type": "baselayer", "version": "1", "minzoom": str(a.zmin), "maxzoom": str(a.zmax),
        "bounds": a.bounds, "attribution": "© OpenStreetMap-bidragsgivare (ODbL)", "description": "Rasterkarta renderad ur Protomaps Basemap (OSM)"}
db.execute("DELETE FROM metadata"); db.executemany("INSERT INTO metadata VALUES (?,?)", meta.items()); db.commit()

have = set(db.execute("SELECT zoom_level, tile_column, tile_row FROM map").fetchall())
def todo():
    for z in range(a.zmin, a.zmax + 1):
        for (zz, x, y) in tiles(z):
            if (zz, x, (1 << zz) - 1 - y) not in have: yield zz, x, y

total = sum(1 for z in range(a.zmin, a.zmax + 1) for _ in tiles(z))
print(f"rutor i området z{a.zmin}-{a.zmax}: {total}, redan hämtade: {len(have)}", flush=True)

def get(t):
    z, x, y = t
    for attempt in range(4):
        try:
            with urllib.request.urlopen(f"{a.url}/{z}/{x}/{y}.{a.ext}", timeout=120) as r: return t, r.read()
        except urllib.error.HTTPError as ex:
            if ex.code == 404: return t, None
        except Exception: pass
        time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"gav upp: {t}")

done = len(have); t0 = time.time(); fails = 0; lock = threading.Lock()
batch = 0
with ThreadPoolExecutor(a.workers) as ex:
    # i omgångar så att minnet hålls nere och Ctrl+C lämnar en konsekvent databas
    it = todo()
    while True:
        chunk = [t for _, t in zip(range(a.workers * 40), it)]
        if not chunk: break
        for (z, x, y), data in ex.map(get, chunk):
            if data is None: fails += 1; continue
            tid = hashlib.md5(data).hexdigest()
            db.execute("INSERT OR IGNORE INTO images VALUES (?,?)", (tid, data))
            db.execute("INSERT OR IGNORE INTO map VALUES (?,?,?,?)", (z, x, (1 << z) - 1 - y, tid))
            done += 1
        db.commit()
        if (done // 500) != ((done - len(chunk)) // 500) or True:
            rate = (done - len(have)) / max(time.time() - t0, 1)
            print(f"{done}/{total} ({100*done//total}%)  {rate:.1f} rutor/s  z{chunk[-1][0]}", flush=True)
db.execute("PRAGMA wal_checkpoint(TRUNCATE)"); db.commit()
print(f"klart: {done} rutor, {fails} saknades (404)")
