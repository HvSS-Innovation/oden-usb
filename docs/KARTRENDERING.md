# Rendera kartan (Sverige, PMTiles)

Obsidians Map View ritar bara rasterrutor, men källfilen från Protomaps är vektordata. Renderingen görs **en gång**, på valfri
maskin med Docker, och resultatet (`sverige.pmtiles`) laddas upp och används av alla bygg. Skriptet är
`build/scripts/map/render-map.sh`. Det gör allt: hämtar källan, skapar stilen, startar en tileserver, renderar rutorna
och konverterar till PMTiles.

## Krav på maskinen
- Linux x86_64 med **Docker** (kommandot `docker` ska fungera för din användare), `git`, `curl`, `python3`, `tar`, `sha256sum`.
- Nät (källfilen är 4,1 GB; dessutom Docker-avbildningar och npm-paket).
- Diskutrymme (skriptet kontrollerar): minst 10 GB för z12–13 och 15 GB för z14 (källa 4,1 GB + MBTiles + PMTiles).
- Rendering är processorbunden: fler kärnor ger nästan linjärt snabbare resultat. Minne: ca 1 GB per parallell arbetare.

## Skaffa kartan (välj ett sätt)
Kartan är en enda fil, `sverige.pmtiles` (rasterrutor, z0–14, ca 1,8–2,25 GB). Den ligger inte i repot.
1. **Du har redan filen eller en adress till den** (snabbast). Lägg filen i `build/cache/assets/maps/sverige.pmtiles`
   för `karta` och `karta-ai`. För `minimal` sätter du dessutom `ODEN_MAPS_URL` (och helst `ODEN_MAPS_SHA256`) i `.env`.
   Hämta och kontrollera: `curl -fL -o build/cache/assets/maps/sverige.pmtiles "$ODEN_MAPS_URL"` och
   `sha256sum build/cache/assets/maps/sverige.pmtiles` (ska stämma med `ODEN_MAPS_SHA256`).
2. **Rendera själv** från OpenStreetMap-data (Protomaps, ca 4,1 GB): `build/scripts/map/render-map.sh`, se "Så kör du" nedan.
   Det ger samma sorts fil men med dagens data, så SHA256 blir en annan.
   **Färsk data:** sätt `PLANET_DATE=ÅÅÅÅMMDD` (ett datum som finns på `build.protomaps.com`, dagsbygge). Skriptet beskär då Sverige
   ur det bygget med `pmtiles extract` (prövat 2026-11-22 mot 20261120: ca 4,7 GB nedladdat, några minuter) i stället för den låsta
   källfilen från 2026-05. Beskärningen tog 2026-11-22 ca 13 min (snabb till 98 %, sedan långsamt från Protomaps), inte några minuter. Använd en **ny, tom `WORK`-mapp**: redan renderade rutor i en gammal `WORK` återanvänds och skulle ge gammal data.
   Källans datum, storlek och SHA256 skrivs ut; anteckna dem. Exempel:
   `PLANET_DATE=20261120 ZMAX=14 WORKERS=16 WORK=/data/karta-ny build/scripts/map/render-map.sh`

## Behöver du mer kraft? Hyr en tillfällig server
Renderingen z0–14 gick 2026-11-22 med ca 550 rutor/s (`SERVERS=3 WORKERS=48`) på cpx62; de sista ca 950 000 rutorna tog under 30 minuter; på en vanlig dator räkna med flera timmar (tabellen nedan
visar ca 7 timmar för z14), och 15 GB disk behövs. Gör den på en tillfällig molnserver och radera den direkt efteråt (så gjordes kartan 2026-11-20: Hetzner cpx62,
Ubuntu 24.04, Docker). Kostnaden är liten men kolla Hetzners aktuella pris.
```bash
# Skapa (kräver hcloud CLI och ett Hetzner-projekt med API-token; eller gör det i konsolen)
# --location hel1 är billigast (ca 0,22 EUR/h; 0,26 i fsn1/nbg1). cpx62 har 640 GB disk, så /data på rotdisken räcker.
hcloud server create --name karta --type cpx62 --location hel1 --image ubuntu-24.04 --ssh-key <nyckel-id>
# Hetzner återanvänder IP-adresser: använd -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no, annars stoppar en gammal host-nyckel.
ssh root@<ip>
curl -fsSL https://get.docker.com | sh && apt-get install -y git tmux python3
git clone https://github.com/HvSS-Innovation/oden-usb.git && cd oden-usb
tmux new -s karta
ZMAX=14 WORKERS=48 SERVERS=3 WORK=/data/karta build/scripts/map/render-map.sh
# Hämta hem resultatet och kontrollera:
scp root@<ip>:/data/karta/sverige.pmtiles build/cache/assets/maps/ && sha256sum build/cache/assets/maps/sverige.pmtiles
# RADERA servern så snart du har filen (annars fortsätter fakturan):
hcloud server delete karta
```
Rekommendation: `cpx62` (16 vCPU) för full rendering; en mindre server (t.ex. 8 vCPU) fungerar men tar dubbelt så lång tid.
Minne räcker med ca 1 GB per arbetare. Lägg filen sedan på er publika lagring och sätt `ODEN_MAPS_URL` (se ovan).
**Slipp ladda ned filen till din egen maskin:** kopiera `.env` (R2-nycklarna) till servern, ladda upp därifrån med `rclone` (`RCLONE_CONFIG_R2_*` ur miljön, `copyto` till `oden/maps/`), verifiera med `rclone cat … | sha256sum` mot `sha256sum` av originalet, och radera servern.
Samma upplägg går att använda för ISO-bygget om din dator är för svag. Bygget av `karta-ai` ger en 14,5 GB stor ISO och cachen är 13 GB, så ta en server med gott om disk (hundratals GB) och mät själv.

## Välj zoomdjup
Antal rutor inom Sveriges ram (10,54–24,17 °Ö, 55,20–69,07 °N), per nivå och sammanlagt:

| Till och med | Rutor (nivån) | Rutor (totalt) | Ungefärlig tid* | Ungefärlig storlek** | Duger till |
|---|---|---|---|---|---|
| z10 | 3 480 | 4 770 | någon minut | ~25 MB | översikt, test |
| z11 | 13 667 | 18 437 | ~7 min | ~60 MB | länsnivå |
| **z12** | 54 322 | 72 759 | ~25 min | ~200 MB | stad/kommun (**PoC**) |
| z13 | 215 592 | 288 351 | ~1,7 timmar | ~0,8 GB | stadsdel |
| **z14** | 858 360 | 1 146 711 | ~7 timmar | ~3 GB (2,5–5) | kvarter, gator (mål) |
| z15 | 3 425 436 | 4 572 147 | ~1 dygn+ | ~10–12 GB | ej planerat |

\* Mätt: 21–46 rutor/s med 3 parallella arbetare på en delad 4-kärnig maskin (högre när maskinen inte var belastad). En stor server med 16 kärnor och `WORKERS=16` bör ge 3–5 gånger det.
\** Extrapolerat ur mätningen på z0–12: medelstorleken faller med zoomnivån (7 kB vid z0, 5,7 kB vid z9, 3,7 kB vid z11, 3,2 kB vid z12, eftersom skog, åkrar och vatten ger enkla bilder) och ca 29 % av rutorna är identiska och delas. Städer drar upp snittet, så z14 kan bli upp till ca 5 GB. Uppdatera efter första z14-körningen.

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
| `SERVERS` | kärnor/6 | Antal tileserver-containrar. En container utnyttjar bara ca 6 kärnor; mätt på 16 kärnor: ca 205 rutor/s med 1, ca 550 med 3 |
| `PLANET_DATE` | (låst källa) | ÅÅÅÅMMDD, färsk data ur Protomaps dagsbygge (se ovan) |
| `ZMAX` | 14 | Högsta zoomnivå som renderas |
| `ZMIN` | 0 | Lägsta |
| `WORKERS` | antal kärnor | Parallella arbetare totalt (renderar-poolen delas på `SERVERS`). Med `SERVERS=3` på 16 kärnor: `WORKERS=48` |
| `WORK` | `./map-work` | Arbetsmapp; här hamnar allt |
| `PORT` | 18081 | Lokal port för tileservern (bara 127.0.0.1) |
| `BOUNDS` | Sverige | `väst,syd,öst,nord` i grader, t.ex. för en testregion |

Provkör på en liten region först, t.ex. Uppsala–Stockholm: `BOUNDS=17.0,59.2,18.4,60.0 ZMAX=13 WORK=/tmp/test ...`.

## Vad skriptet gör
1. Hämtar `sweden-osm.pmtiles` (4 092 223 980 byte) och kontrollerar SHA256 (`59fe0b51…3027a`, OSM-data 2026-05-20).
2. Skapar MapLibre-stilen `oden` med **@protomaps/basemaps 5.7.2** (tema *light*, svenska namn) i en `node:22-slim`-container.
3. Hämtar typsnitt och sprites från `protomaps/basemaps-assets` (låst commit `028c18f`).
4. Startar `SERVERS` st **tileserver-gl v5.7.0** (Docker) som läser PMTiles direkt och renderar rutor som WebP (kvalitet 85, 256 px).
5. `fetch-tiles.py` hämtar (jämnt fördelat över servrarna) varje ruta inom ramen och skriver dem till en MBTiles-fil (SQLite, identiska rutor delas, återupptagbar).
6. Hämtar **go-pmtiles v1.31.2** (SHA256-kontrollerad) och konverterar MBTiles till `sverige.pmtiles`.
7. Skriver ut storlek och SHA256 för resultatet.

Alla versioner står överst i skriptet. Resultatet är inte bit-identiskt mellan körningar, därför låser vi **den uppladdade filens** SHA256, inte
receptet.

## Efter renderingen
1. **Kontrollera** (valfritt men bra):
   ```bash
   $WORK/pmtiles-bin/pmtiles show $WORK/sverige.pmtiles        # zoomnivåer, bounds, antal rutor
   mkdir -p /tmp/k && cp $WORK/sverige.pmtiles /tmp/k/ && $WORK/pmtiles-bin/pmtiles serve /tmp/k --port=8081 --interface=127.0.0.1 &
   curl -s -o t.webp -w '%{http_code}\n' http://127.0.0.1:8081/sverige/8/139/74.webp     # 200, öppna t.webp
   ```
2. **Ladda upp** filen (S3, Google Drive eller liknande med direktlänk) och notera URL, SHA256 och storlek i byte.
3. **Minimal-varianten** (hämtar kartan vid första start): sätt `ODEN_MAPS_URL` (och valfritt `ODEN_MAPS_SHA256`) i miljön eller `.env`. `build.sh` läser storlek och SHA256 ur filen i `build/cache/assets/maps/` och skriver `assets.lock`. Alternativ: en lokal, ignorerad `build/maps.lock` (format i `build/maps.lock.example`). Stickan måste hinna ha plats: partitionen för kartor räknas ur summan av byte.
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
(inte ännu inlagd i Map View; se `plan/arkiv/05-kartor-pmtiles.md`).

## Efter en ny rendering: publicera
1. Kontrollera filen (`pmtiles show`, öppna några rutor) och notera SHA256 och byte.
2. Ladda upp till den publika lagringen under ett nytt namn (skriv inte över den gamla filen som äldre ISO-filer pekar på).
3. Uppdatera `ODEN_MAPS_URL` och `ODEN_MAPS_SHA256` i `.env`, lägg filen i `build/cache/assets/maps/sverige.pmtiles` och bygg om
   (`ODEN_VARIANTS=minimal,karta,karta-ai`). Uppdatera datum, storlek och SHA256 i `docs/STATUS.md` och `docs/KALLOR.md`.
