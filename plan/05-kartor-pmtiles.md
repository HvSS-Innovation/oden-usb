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

## Rendering till raster (görs en gång, inte i varje bygge)
Skriptet `build/scripts/map/render-map.sh` gör hela kedjan (källa, stil, tileserver-gl, rutor, PMTiles). Så körs det på en annan maskin,
vilka zoomdjup som är rimliga (tider och storlekar) och hur resultatet förs in i bygget står i **`docs/KARTRENDERING.md`**.
Prov (2026-11-20): tileserver-gl 5.7.0 renderar Protomaps-stilen med svenska namn, ca 21 rutor/s med 3 arbetare. Vektorfilen räcker till z15, men
z14 (1,15 miljoner rutor, ca 8 GB) är målet; z12 används för PoC. Leaflet förstorar över sista nivån (`maxNativeZoom`, ställs via `build/map.conf`).

## Uppgifter
1. Kartfilen ligger på p3: `/srv/oden-assets/maps/sverige.pmtiles`. Ny karta = ny stick.
2. systemd-user-tjänst:
   ```
   ExecStart=/opt/pmtiles/pmtiles serve /srv/oden-assets/maps --port 8081 --interface=127.0.0.1 --cors=app://obsidian.md
   ```
   (`serve` exponerar `/{namn}/{z}/{x}/{y}.{png|webp|jpg}` för raster; kontrollera exakt flaggsyntax mot den pinnade versionen.)
   Odens webbgränssnitt använder 8080, därför ligger kartservern på 8081.
3. Ändra kartkälla i valvets `.obsidian/plugins/obsidian-map-view/data.json` (`obsidian-config/map-view-data.json` i ODEN-analys):
   `http://127.0.0.1:8081/sverige/{z}/{x}/{y}.webp` (eller `.png`). Ta bort CartoDB-nyckelinstruktionen ur det som visas för användaren.
   Lägg in attribution (© OpenStreetMap).
4. Bekräfta att Obsidian får hämta från `127.0.0.1`.
5. Map View: `maxZoom` på kartkällan (= högsta renderade nivå) och `letZoomBeyondMax` så att Leaflet förstorar. Sätts av `stage.sh` ur `build/map.conf`.

## Klart när
- Datorn utan nät visar kartan i Obsidian med korrekt zoomintervall och markörer.
- Ingen `API key required`-text och inga externa tile-anrop (verifiera i paketfångst).
