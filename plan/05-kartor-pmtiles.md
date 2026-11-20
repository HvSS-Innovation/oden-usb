# Steg 05: Kartor via go-pmtiles

## Princip
Map View i Obsidian är Leaflet och vill ha raster-rutor på `{z}/{x}/{y}`. `go-pmtiles serve` serverar en raster-PMTiles-fil
som exakt sådana rutor, lokalt, utan nät.

## Källa
`https://kartverktyget.s3.eu-central-003.backblazeb2.com/sweden-osm.pmtiles` (4,1 GB, Last-Modified 2026-05-27):
- SHA256 `59fe0b51666c9ab95a03fce87bb5e8aced22a4edcba25560dfb176884bf3027a`, 4 092 223 980 byte (förs in i `artifacts.lock`).
- **Vektor** (MVT, gzip), PMTiles v3, **Protomaps Basemap** v4.14.8 byggd med planetiler 0.10.1.
- OSM-data från 2026-05-20, licens ODbL (attribution: © OpenStreetMap).
- Zoom 0–15, Sverige (bounds 10.54,55.20 – 24.17,69.07). Lager: boundaries, buildings, earth, landcover,
  landuse, places, pois, roads, water.
- Map View kan inte rita vektor, så filen renderas till raster (se nedan).
- Filen ligger inte i repot (`.gitignore` utesluter `*.mbtiles` och `*.pmtiles`).

## Rendering till raster (gjord 2026-11-20, görs inte om i varje bygge)
Utförd på en tillfällig Hetzner-server (cpx62, Ubuntu 24.04, Docker), raderad efteråt. Metod:
1. `maptiler/tileserver-gl` v5.7.0 med `sweden-osm.pmtiles` som källa och stil genererad med `@protomaps/basemaps`
   (`layers("protomaps", namedFlavor("light"), {lang:"sv"})`). Typsnitt och sprites (`light`) från `protomaps/basemaps-assets`.
2. Ett Python-skript hämtade alla rutor z0–14 inom bounds som WebP (48 trådar, ca 330 rutor/s, ca 50 min) och skrev
   raster-MBTiles.
3. `pmtiles convert raster.mbtiles sverige.pmtiles` (go-pmtiles 1.31.2, 2 min).

Resultat:
- 1 146 711 adresserade rutor (733 277 unika; identiska rutor, främst hav, delas), WebP 256 px, z0–14.
  Rutor per zoom: z12 54 322, z13 215 592, z14 858 360.
- **Storlek 2 250 443 850 byte (2,25 GB)**, inte de 10–25 GB som först uppskattades. z15 är därför inte uteslutet av
  utrymmesskäl (ca 4 gånger fler rutor, grovt 6–9 GB); det är en rimlig uppföljning om z14 visar sig för grovt.
- SHA256 `85659a9ed5e97e4e87c005e752177f8e07d1bed1cd4607b11d9783d0803e1d8e` (förs in i `artifacts.lock`).
- Uppladdad till `https://kartverktyget.s3.eu-central-003.backblazeb2.com/sverige-raster.pmtiles` (verifierad storlek,
  range-requests fungerar). Källfilen `sweden-osm.pmtiles` ligger kvar oförändrad på samma bucket.
- Leaflet skalar upp z14 (`maxNativeZoom: 14`).
- Oklart: i en testruta (z12, skogsområde) syntes raka diagonala linjer i landcover. Kontrollera visuellt i Obsidian
  innan filen frysts som slutlig.

Alternativ utan rendering: `protomaps-leaflet` ritar just detta vektorformat direkt i Leaflet, men Map View stöder det inte
och skulle behöva patchas. Raster är enklare att driva.

## Uppgifter
1. Hämta `sverige-raster.pmtiles` från B2 (kontrollera SHA256) och lägg den på p3 som `/srv/oden-assets/maps/sverige.pmtiles`. Ny karta = ny stick.
2. systemd-user-tjänst:
   ```
   ExecStart=/opt/pmtiles/pmtiles serve /srv/oden-assets/maps --port 8080 --bind 127.0.0.1 --cors=app://obsidian.md
   ```
   (`serve` exponerar `/{namn}/{z}/{x}/{y}.{png|webp|jpg}` för raster; kontrollera exakt flaggsyntax mot den pinnade versionen.)
   Kontrollera att port 8080 inte krockar med Odens webbgränssnitt.
3. Ändra kartkälla i valvets `.obsidian/plugins/obsidian-map-view/data.json` (`obsidian-config/map-view-data.json` i ODEN-analys):
   `http://127.0.0.1:8080/sverige/{z}/{x}/{y}.webp` (eller `.png`). Ta bort CartoDB-nyckelinstruktionen ur det som visas för användaren.
   Lägg in attribution (© OpenStreetMap).
4. Bekräfta att Obsidian får hämta från `127.0.0.1`.
5. Sätt `maxNativeZoom: 14` i Map View och en högre max-zoom (t.ex. 17) så att Leaflet skalar upp z14-rutor.

## Klart när
- Datorn utan nät visar kartan i Obsidian med korrekt zoomintervall och markörer.
- Ingen `API key required`-text och inga externa tile-anrop (verifiera i paketfångst).
