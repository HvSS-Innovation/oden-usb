# Status: ODEN-stick

Uppdaterad 2026-11-19, gren `feature/stick-bygge` (ej pushad). Ingen del har ännu körts på en riktig stick eller dator.
Förklaring: **Klart** = skrivet och testat så långt det går utan hårdvara. **Skrivet** = kod finns men är inte körd.
**Kvar** = inte gjort.

## Läge i korthet
- Bygg-pipelinen är på plats och alla artefakter är låsta. Oden för Linux bygger och startar i en Debian 13-container.
- Hela bilden (live-build), `make-stick.sh`, krypterad persistens och boot är **inte körda**. Det är nästa stora risk.
- Kartan (rasterrendering) är inte gjord, och utan den visar stickan ingen karta.

## Per steg (se `plan/`)
| Steg | Status | Detaljer |
|---|---|---|
| 00 Beslut och kravspec | Klart | `docs/KRAVSPEC.md`, hotmodell beslutad |
| 01 Bygg-pipeline | Skrivet | `build.sh`, `fetch.sh`, låsning, SBOM, `bump.sh`, `make-stick.sh`. Testat: syntax, partitionering på gles fil, `tests/run.sh`. Ej testat: live-build-bygget, `dd`/`mkfs`/`mount` mot en enhet, att live-builds iso-hybrid-ISO (efterbehandlad till GPT med p1 ISO-data + p2 EFI) har exakt 2 partitioner. Verifierat med sfdisk, ej bootat |
| 02 Mjukvara i bilden | Delvis klart | Oden-binär byggd (`/opt/oden/oden`, 197 MB) och rökprovad; `stage.sh` testad mot riktiga artefakter. Kvar: `config.ini`- och Obsidian-förkonfiguration, `--no-sandbox` för Obsidian, versionsnummer i binären (visar `v0.0.0-dev`) |
| 03 Krypterad persistens | Skrivet | `oden-firstboot`, `oden-wipe`, `oden-persist-dev`. Endast syntaxkontroll. Ej verifierat: live-boots upplåsning med frasen, beteende vid fel fras, `noatime`, strömavbrottstest |
| 04 Nät, Signal, TAK | Delvis | NetworkManager, nftables, timesyncd och wifi-firmware finns i bilden (ej provade). Kvar: tydlig statusindikator för frånkopplat läge. Signal-länkning och TAK sköts av Odens eget gränssnitt (ej provat i bilden) |
| 05 Kartor | Kvar | Källan (vektor, 4 GB) är låst. Rasterrendering av z0–14 är inte gjord. `pmtiles.service` är skriven men flaggsyntaxen för `serve` är overifierad. Map View-konfigurationen mot `127.0.0.1:8081` är inte gjord. p3 monteras via `fstab` (overifierat) |
| 06 AI / Ollama | Skrivet | `ollama.service`, RAM-kontroll, NVIDIA-paket i paketlistan, Ollama låst. Modeller (`qwen3-vl:4b`, `qwen3:8b`) är inte hämtade. Inget provat |
| 07 Test, härdning, dokumentation | Delvis | Användarguide, adminguide, felsökning och mall för HW-matris skrivna. Kvar: maskinvarutest, E2E mot ODEN-analys, paketfångst, strömavbrott, `oden-wipe`-test |

## Artefakter (`build/artifacts.lock`)
| Artefakt | Version | Status |
|---|---|---|
| Oden (byggd) | 4.2.1, commit c10db739 | Byggd lokalt, ej reproducerbar (pip `>=`) |
| signal-cli | 0.14.5 | Låst, inbyggd i Oden |
| Temurin JRE | 25.0.5.1+2 | Låst, inbyggd i Oden |
| ODEN-valv | 1.6.3 | Låst, uppackning testad |
| Obsidian | 1.15.1 | Låst, extraktion testad |
| go-pmtiles | 1.31.2 | Låst, uppackning testad |
| Ollama | 0.40.16 | Låst via GitHubs digest, aldrig nedladdad eller uppackad |
| sweden-osm.pmtiles | OSM 2026-05-20 | Låst men används inte av bilden (källa för rastret) |

## Kända problem och beslut att ta
- `fetch.sh` hämtar `sweden-osm.pmtiles` (4 GB) vid varje färsk cache trots att bilden inte använder den. Förslag: ta ur lås-filen tills steg 05.
- Oden är en "onefile"-binär som packar upp sig själv (ca 200 MB) i `/tmp` (RAM) vid varje start. Alternativ: bygga "onedir".
- Oden kan öppna webbläsaren själv vid första start (`_welcome_first_start`), och stickan autostartar också en webbläsare. Ej provat.
- Oden-GUI lyssnar på `127.0.0.1:8080` enligt planen, men att inga andra portar är öppna (`ss -tulpn`) är inte kontrollerat.
- Fel lösenfras vid boot: live-boot kan starta utan persistens eller upprepa frågan. Ej verifierat; skripten förutsätter det förra.
- Hård strömavstängning och SQLite WAL i Oden är inte undersökt.
- Obsidian-pluginernas version mot Obsidian 1.15.1 är inte kontrollerad.

## Nästa steg i ordning
1. Ta bort `sweden-osm.pmtiles` ur lås-filen (eller flytta den till ett eget kartsteg).
2. `./build/build.sh` hela vägen: första riktiga live-build. Räkna med att åtgärda paketnamn och hook-fel.
3. Boota `build/out/oden.iso` i QEMU/OVMF; kontrollera att den har 2 partitioner, att `oden.service` startar och att skrivbordet kommer upp.
4. Rendera rasterkartan (steg 05) och fyll i `build/cache/assets/maps/`.
5. Skriv en riktig stick med `make-stick.sh`; testa första start, omstart med lösenfras, fel lösenfras och `oden-wipe` (steg 03).
6. Förkonfigurera Oden och Obsidian (steg 02, uppgift 7) och koppla kartan i Map View.
7. Maskinvarumatris, paketfångst och E2E (steg 07).

## Commits på grenen (sedan `main`)
Plan, Steg 00–01, Steg 02 (konfig), Steg 03, `make-stick.sh`, staging, steg 07-dokument, bygg av Oden och `bump.sh`,
adminguide. Se `git log main..feature/stick-bygge`.
