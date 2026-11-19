# Steg 05: Kartor via go-pmtiles

## Princip
Map View i Obsidian är Leaflet och vill ha raster-rutor på `{z}/{x}/{y}`. `go-pmtiles serve` serverar en PMTiles-fil
som exakt sådana rutor, lokalt, utan nät.

## Uppgifter
1. Kartfilen ligger på p3: `/srv/oden-assets/maps/sverige.pmtiles`. Ny karta = ny stick.
2. systemd-user-tjänst:
   ```
   ExecStart=/opt/pmtiles/pmtiles serve /srv/oden-assets/maps --port 8080 --bind 127.0.0.1 --cors=app://obsidian.md
   ```
   (`serve` exponerar `/{namn}/{z}/{x}/{y}.{png|webp|jpg}` för raster; kontrollera exakt flaggsyntax mot den pinnade versionen.)
   Kontrollera att port 8080 inte krockar med Odens webbgränssnitt.
3. Ändra kartkälla i valvets `.obsidian/plugins/obsidian-map-view/data.json` (`obsidian-config/map-view-data.json` i ODEN-analys):
   `http://127.0.0.1:8080/sverige/{z}/{x}/{y}.png`. Ta bort CartoDB-nyckelinstruktionen ur det som visas för användaren.
4. Bekräfta att Obsidian får hämta från `127.0.0.1`.
5. Sätt max-zoom i Map View så att den matchar PMTiles-filens zoomintervall (annars tomma rutor).

## Om filen är vektor (MVT)
Map View kan inte rita vektorrutor. Enklast: rendera till raster-PMTiles i förväg, vid bygget.
Bekräfta formatet innan steg 05 påbörjas: `pmtiles show fil.pmtiles` ger `tile type`.

## Klart när
- Datorn utan nät visar kartan i Obsidian med korrekt zoomintervall och markörer.
- Ingen `API key required`-text och inga externa tile-anrop (verifiera i paketfångst).
