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
1. Kör `tileserver-gl` (container) med PMTiles-filen som källa och Protomaps-stilen (`@protomaps/basemaps`, t.ex. tema
   `light`) med typsnitt och sprites från `protomaps/basemaps-assets` lokalt.
2. Ett skript hämtar alla rutor z0–14 inom bounds från tileservern och skriver en raster-MBTiles (webp).
3. `pmtiles convert raster.mbtiles sverige.pmtiles`.
4. Resultatet blir en egen artefakt i `artifacts.lock` (SHA256). Byggen använder den färdiga filen.

Grov uppskattning: drygt 1 miljon rutor på z0–14, storlek i storleksordningen 10–25 GB. z15 skulle ge ca 4 gånger fler
rutor och utelämnas; Leaflet skalar upp z14 (`maxNativeZoom: 14`). Mät efter första renderingen; räcker utrymmet inte: z13.

Alternativ utan rendering: `protomaps-leaflet` ritar just detta vektorformat direkt i Leaflet, men Map View stöder det inte
och skulle behöva patchas. Raster är enklare att driva.

## Uppgifter
1. Kartfilen ligger på p3: `/srv/oden-assets/maps/sverige.pmtiles`. Ny karta = ny stick.
2. systemd-user-tjänst:
   ```
   ExecStart=/opt/pmtiles/pmtiles serve /srv/oden-assets/maps --port 8081 --bind 127.0.0.1 --cors=app://obsidian.md
   ```
   (`serve` exponerar `/{namn}/{z}/{x}/{y}.{png|webp|jpg}` för raster; kontrollera exakt flaggsyntax mot den pinnade versionen.)
   Odens webbgränssnitt använder 8080, därför ligger kartservern på 8081.
3. Ändra kartkälla i valvets `.obsidian/plugins/obsidian-map-view/data.json` (`obsidian-config/map-view-data.json` i ODEN-analys):
   `http://127.0.0.1:8081/sverige/{z}/{x}/{y}.webp` (eller `.png`). Ta bort CartoDB-nyckelinstruktionen ur det som visas för användaren.
   Lägg in attribution (© OpenStreetMap).
4. Bekräfta att Obsidian får hämta från `127.0.0.1`.
5. Sätt `maxNativeZoom: 14` i Map View och en högre max-zoom (t.ex. 17) så att Leaflet skalar upp z14-rutor.

## Klart när
- Datorn utan nät visar kartan i Obsidian med korrekt zoomintervall och markörer.
- Ingen `API key required`-text och inga externa tile-anrop (verifiera i paketfångst).
