# Steg 05: Kartor via go-pmtiles

## Princip
Map View i Obsidian är Leaflet och vill ha raster-rutor på `{z}/{x}/{y}`. `go-pmtiles serve` serverar en raster-PMTiles-fil
som exakt sådana rutor, lokalt, utan nät.

## Källa (mottagen 2026-11-19)
`osm-2020-02-10-v3.11_europe_sweden.mbtiles`, 1,8 GB:
- **Vektor** (MVT/pbf, gzip), OpenMapTiles-schema 3.11, från MapTiler/openmaptiles.com.
- Zoom 0–14, Sverige (bounds 10.54,55.03 – 24.22,69.07), OSM-data från 2020-02-10, `scheme: tms`.
- Map View kan inte rita vektor, så filen måste renderas till raster (se nedan).
- **Kontrollera licensen.** MapTilers OpenMapTiles-nedladdningar har egna villkor utöver OSM:s ODbL.
  Filen ska inte ligga i det publika repot (`.gitignore` utesluter `*.mbtiles` och `*.pmtiles`).
- Alternativ om licensen eller datans ålder inte duger: generera nya vektorrutor i samma schema med `planetiler`
  från Geofabriks Sverige-extrakt (ODbL), och kör sedan samma rendering.

## Rendering till raster (görs en gång, inte i varje bygge)
1. Kör `tileserver-gl` (container) med vektorfilen och en OpenMapTiles-stil (t.ex. OSM Bright) med typsnitt och sprites lokalt.
2. Ett skript hämtar alla rutor z0–14 inom bounds från tileservern och skriver en raster-MBTiles (webp eller png).
3. `pmtiles convert raster.mbtiles sverige.pmtiles`.
4. Resultatet blir en egen artefakt i `artifacts.lock` (SHA256). Byggen använder den färdiga filen.

Grov uppskattning: drygt 1 miljon rutor på z0–14; storlek i storleksordningen 10–25 GB. Mät efter första renderingen
och välj webp om png blir för stort. Räcker det inte på en 64 GB-stick: begränsa till z13.

## Uppgifter
1. Kartfilen ligger på p3: `/srv/oden-assets/maps/sverige.pmtiles`. Ny karta = ny stick.
2. systemd-user-tjänst:
   ```
   ExecStart=/opt/pmtiles/pmtiles serve /srv/oden-assets/maps --port 8080 --bind 127.0.0.1 --cors=app://obsidian.md
   ```
   (`serve` exponerar `/{namn}/{z}/{x}/{y}.{png|webp|jpg}` för raster; kontrollera exakt flaggsyntax mot den pinnade versionen.)
   Kontrollera att port 8080 inte krockar med Odens webbgränssnitt.
3. Ändra kartkälla i valvets `.obsidian/plugins/obsidian-map-view/data.json` (`obsidian-config/map-view-data.json` i ODEN-analys):
   `http://127.0.0.1:8080/sverige/{z}/{x}/{y}.webp` (eller `.png`). Ta bort CartoDB-nyckelinstruktionen ur det som visas för användaren.
   Lägg in attribution (© OpenMapTiles © OpenStreetMap contributors).
4. Bekräfta att Obsidian får hämta från `127.0.0.1`.
5. Sätt max-zoom i Map View till 14 (filens maxzoom); Leaflet kan skala upp z14-rutor för djupare zoom (`maxNativeZoom: 14`).

## Klart när
- Datorn utan nät visar kartan i Obsidian med korrekt zoomintervall och markörer.
- Ingen `API key required`-text och inga externa tile-anrop (verifiera i paketfångst).
