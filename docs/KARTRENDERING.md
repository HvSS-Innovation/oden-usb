# Rendera kartan (Sverige, PMTiles)

Obsidians Map View ritar bara rasterrutor, men källfilen från Protomaps är vektordata. Renderingen görs **en gång**, på valfri
maskin med Docker, och resultatet (`sverige.pmtiles`) laddas upp och används av alla bygg. Skriptet är
`build/scripts/map/render-map.sh`. Det gör allt: hämtar källan, skapar stilen, startar en tileserver, renderar rutorna
och konverterar till PMTiles.

## Krav på maskinen
- Linux x86_64 med **Docker** (kommandot `docker` ska fungera för din användare), `git`, `curl`, `python3`, `tar`, `sha256sum`.
- Nät (källfilen är 4,1 GB; dessutom Docker-avbildningar och npm-paket).
- Diskutrymme (skriptet kontrollerar): minst 10 GB för z12, 15 GB för z13, 30 GB för z14.
- Rendering är processorbunden: fler kärnor ger nästan linjärt snabbare resultat. Minne: ca 1 GB per parallell arbetare.

## Välj zoomdjup
Antal rutor inom Sveriges ram (10,54–24,17 °Ö, 55,20–69,07 °N), per nivå och sammanlagt:

| Till och med | Rutor (nivån) | Rutor (totalt) | Ungefärlig tid* | Ungefärlig storlek** | Duger till |
|---|---|---|---|---|---|
| z10 | 3 480 | 4 770 | någon minut | ~30 MB | översikt, test |
| z11 | 13 667 | 18 437 | ~15 min | ~100 MB | länsnivå |
| **z12** | 54 322 | 72 759 | ~1 timme | ~400 MB | stad/kommun (**PoC**) |
| z13 | 215 592 | 288 351 | ~4 timmar | ~1,8 GB | stadsdel |
| **z14** | 858 360 | 1 146 711 | ~15 timmar | ~8 GB | kvarter, gator (mål) |
| z15 | 3 425 436 | 4 572 147 | dagar | ~30 GB | ej planerat |

\* Mätt: ca 21 rutor/s med 3 parallella arbetare på en delad 4-kärnig maskin. En stor server med 16 kärnor och `WORKERS=16` bör ge 4–5 gånger det.
\** Uppskattning ur medelstorleken på de lägre nivåerna (5–8 kB per ruta, identiska havsrutor delas). Mät och uppdatera här efter första körningen.

Map View förstorar rutorna över sista nivån (`letZoomBeyondMax`), så z12 går att använda ända in till gatunivå, men suddigt.
**Sätt `MAP_MAXZOOM` i `build/map.conf` till det ZMAX du renderade.**

## Så kör du
```bash
git clone https://github.com/HvSS-Innovation/oden-usb.git && cd oden-usb      # eller kopiera mappen build/scripts/map/
# Hela Sverige, z0-14, på en maskin med 16 kärnor (ca 3-4 timmar):
ZMAX=14 WORKERS=16 WORK=/data/karta build/scripts/map/render-map.sh
# PoC, z0-12:
ZMAX=12 WORKERS=3 WORK=/data/karta build/scripts/map/render-map.sh
```
Kör gärna i `tmux`/`screen` eller med `nohup ... > render.log 2>&1 &`. Skriptet kan **avbrytas och köras om**: nedladdningen återupptas,
stilen återanvänds och redan renderade rutor hoppas över (de ligger i `$WORK/sverige-z<ZMIN>-<ZMAX>.mbtiles`).

| Variabel | Standard | Betydelse |
|---|---|---|
| `ZMAX` | 14 | Högsta zoomnivå som renderas |
| `ZMIN` | 0 | Lägsta |
| `WORKERS` | antal kärnor | Parallella arbetare (och renderar-pool i tileservern) |
| `WORK` | `./map-work` | Arbetsmapp; här hamnar allt |
| `PORT` | 18081 | Lokal port för tileservern (bara 127.0.0.1) |
| `BOUNDS` | Sverige | `väst,syd,öst,nord` i grader, t.ex. för en testregion |

Provkör på en liten region först, t.ex. Uppsala–Stockholm: `BOUNDS=17.0,59.2,18.4,60.0 ZMAX=13 WORK=/tmp/test ...`.

## Vad skriptet gör
1. Hämtar `sweden-osm.pmtiles` (4 092 223 980 byte) och kontrollerar SHA256 (`59fe0b51…3027a`, OSM-data 2026-05-20).
2. Skapar MapLibre-stilen `oden` med **@protomaps/basemaps 5.7.2** (tema *light*, svenska namn) i en `node:22-slim`-container.
3. Hämtar typsnitt och sprites från `protomaps/basemaps-assets` (låst commit `028c18f`).
4. Startar **tileserver-gl v5.7.0** (Docker) som läser PMTiles direkt och renderar rutor som WebP (kvalitet 85, 256 px).
5. `fetch-tiles.py` hämtar varje ruta inom ramen och skriver dem till en MBTiles-fil (SQLite, identiska rutor delas, återupptagbar).
6. Hämtar **go-pmtiles v1.31.2** (SHA256-kontrollerad) och konverterar MBTiles till `sverige.pmtiles`.
7. Skriver ut storlek och SHA256 för resultatet.

Alla versioner står överst i skriptet. Resultatet är inte bit-identiskt mellan körningar, därför låser vi **den uppladdade filens** SHA256, inte
receptet.

## Efter renderingen
1. **Kontrollera** (valfritt men bra):
   ```bash
   build/cache/map-work/pmtiles-bin/pmtiles show $WORK/sverige.pmtiles        # zoomnivåer, bounds, antal rutor
   mkdir -p /tmp/k && cp $WORK/sverige.pmtiles /tmp/k/ && $WORK/pmtiles-bin/pmtiles serve /tmp/k --port=8081 --interface=127.0.0.1 &
   curl -s -o t.webp -w '%{http_code}\n' http://127.0.0.1:8081/sverige/8/139/74.webp     # 200, öppna t.webp
   ```
2. **Ladda upp** filen (S3, Google Drive eller liknande med direktlänk) och notera URL, SHA256 och storlek i byte.
3. **Minimal-varianten** (hämtar kartan vid första start): lägg en rad i `build/maps.lock`:
   `sverige.pmtiles  <url>  <sha256>  <byte>` (`path url sha256 bytes`; se rubrikkommentaren i filen). Stickan måste hinna ha plats: partitionen för kartor räknas ur summan av byte.
4. **Karta- och Karta+AI-varianterna** (kartan ligger på själva ISO:n): lägg filen i `build/cache/assets/maps/sverige.pmtiles`
   (eller i `$ODEN_ASSETS/maps/`) och bygg med `ODEN_VARIANTS=karta` (se `docs/ADMINGUIDE.md`).
5. Sätt `MAP_MAXZOOM` i `build/map.conf` om du inte renderade z14, och bygg om. Utan ombyggnad av valvmallen blir Map View fel inställd.

## Felsökning
| Symptom | Åtgärd |
|---|---|
| `FEL: docker går inte att nå` | Lägg användaren i gruppen `docker`, logga in igen. |
| `tileservern kom aldrig upp` | `docker logs odenmap-render-…` (visas av skriptet). Vanligast: porten är upptagen, sätt `PORT=`. |
| Mycket långsamt | Fler kärnor och `WORKERS=` lika många. Lokal SSD för `WORK`. Håll `ZMAX` nere. |
| Slut på disk | Radera `$WORK/sverige-z*.mbtiles` efter lyckad konvertering. Källfilen (4 GB) kan raderas när renderingen är klar. |
| Tomma rutor i Obsidian över en viss zoom | `MAP_MAXZOOM` i `build/map.conf` är högre än det som renderades. |
| Konvertering misslyckas | Kör om skriptet: rutorna finns kvar, bara steg 6 görs om. |

## Licens
Kartdata © OpenStreetMap-bidragsgivare, ODbL. Protomaps Basemap-stilen är BSD-3, typsnitten (Noto Sans) OFL. Attribution ska synas för användaren
(inte ännu inlagd i Map View; se `plan/05-kartor-pmtiles.md`).
