# Status: ODEN-stick

Uppdaterad 2026-11-22. Allt ligger på `main` (grenen `feature/stick-bygge` är sammanslagen). Vad som hämtas in och varifrån: se [`KALLOR.md`](KALLOR.md).

## Läge i korthet
- Bygg-pipelinen är klar: artefakterna är låsta, Oden för Linux byggs i en Debian 13-container och bilden byggs med live-build (Debian 13, XFCE).
- Systemet är testat på stickor (uppgift från Nicklas, 2026-11-20): start, krypterad persistens, upplåsning vid boot, Oden, Obsidian och den lokala kartan i Map View.
  Resultaten är inte dokumenterade i detalj; maskinvarumatrisen (`HW-MATRIS.md`) är ännu tom.
- Kartan är klar: rasterkartan `sverige-raster-20261120.pmtiles` (zoom 0–14, 1 914 774 924 byte, OSM 2026-11-20) är renderad och uppladdad till R2 (`oden/maps/`). Adress: <https://publik.hv-sog.se/oden/maps/sverige-raster-20261120.pmtiles> (sätts som `ODEN_MAPS_URL` i `.env`). Lokalt och på ISO:n heter filen `sverige.pmtiles` (Map View och kartservern förutsätter namnet).
  `MAP_MAXZOOM=14` i `build/map.conf`.
- ISO-varianterna är ombyggda med den nya kartan (OSM 2026-11-20) och publicerade på `https://publik.hv-sog.se/oden/b81c7d6/`, med kontrollsumma och SBOM (kontrollerade mot de lokala filerna efter uppladdning). Nedladdningssidan på Pages visar dem. Inte provstartade.
  - **karta**: `oden-karta-b81c7d6.iso`, 5 625 151 488 byte, SHA256 `27d6e2c5…e549`.
  - **minimal**: `oden-minimal-b81c7d6.iso`, 3 710 320 640 byte, SHA256 `471238e8…55c7`. Hämtar kartan vid första start från adressen i `assets.lock` i ISO-filen.
  - **karta-ai**: `oden-karta-ai-b81c7d6.iso`, 14 187 233 280 byte, SHA256 `e76861c5…07c5`.
  - Äldre ISO-filer (`9e5e993`, `9773511`, `4b33379`) ligger kvar på R2 men nedladdningssidan länkar bara till `b81c7d6`.
- Sajten (GitHub Pages, https://hvss-innovation.github.io/oden-usb/) publiceras från `site/` vid push till `main`. Pages-jobbet kan ibland falla på ett tillfälligt artefaktfel; kör då om jobbet.

## Per steg (se `plan/`)
| Steg | Status | Detaljer |
|---|---|---|
| 00 Beslut och kravspec | Klart | `KRAVSPEC.md`, hotmodell beslutad |
| 01 Bygg-pipeline | Klart | `build.sh`, `fetch.sh`, artefaktlås, SBOM, `bump.sh`, `make-stick.sh`, `tests/run.sh`. Förkontrollen av `maps.lock` i `build.sh` ignorerar nu kommentarsrader |
| 02 Mjukvara i bilden | Klart | Oden (versionen stämplas ur `artifacts.lock`), signal-cli, JRE, ODEN-valv, Obsidian (valvet registrerat, community-plugins på), go-pmtiles. Det finns ingen kod för `config.ini`-förkonfiguration eller `--no-sandbox` i bygget |
| 03 Krypterad persistens | Klart | `oden-firstboot`, `oden-wipe`, `oden-persist-dev`, `oden-persist-state`, `oden-passphrase-ok` (a-z, A-Z, 0-9 och mellanslag, ingen minsta längd), LUKS-etikett `oden-pending` → `oden` som sista steg |
| 04 Nät, Signal, TAK | Delvis | NetworkManager, nftables, timesyncd och wifi-firmware ingår. Signal-länkning och TAK sköts av Odens eget gränssnitt. Tydlig statusindikator för frånkopplat läge finns inte |
| 05 Kartor | Klart | Raster z0–14 renderat och låst. Map View använder bara den lokala kartan (`stage.sh`, `build/map.conf`) och är provad i Obsidian |
| 06 AI / Ollama | Delvis | `ollama.service`, RAM-kontroll (16 GB) och NVIDIA-paket finns. Modellerna (`qwen3-vl:4b`, `qwen3:8b`, 8 GB) ligger i `build/cache/assets/ollama/` och ingår i `karta-ai`. Inte provkörda på en sticka |
| 07 Test, härdning, dokumentation | Delvis | Användarguide, adminguide, felsökning och HW-mall är skrivna. Kvar att dokumentera: maskinvarumatris, paketfångst, strömavbrott och `oden-wipe` |
| 08 ISO-varianter (Etcher) | Delvis | `karta`, `minimal` och `karta-ai` byggda och publicerade (`karta-ai` inte provstartad). AI-modeller i `minimal` är inte gjorda; `karta-ai` täcker AI |
| 09 ODEN-utseende | Klart | GRUB-tema, Plymouth, bakgrund, inloggning, genvägar, högupplöst skärm och pekplatta |

## Artefakter (`build/artifacts.lock`)
| Artefakt | Version | Status |
|---|---|---|
| Oden (byggd) | 4.2.1, commit c10db739 | Byggd lokalt, ej bit-för-bit reproducerbar (pip `>=`) |
| signal-cli | 0.14.5 | Låst, inbyggd i Oden |
| Temurin JRE | 25.0.5.1+2 | Låst, inbyggd i Oden |
| ODEN-valv | 1.6.3 | Låst |
| Obsidian | 1.15.1 | Låst |
| go-pmtiles | 1.31.2 | Låst |
| Ollama | 0.40.16 | Låst via GitHubs digest |
| sverige-raster-20261120.pmtiles | OSM 2026-11-20, z0–14 | SHA256 `8434482de33755c1b1fdc7fdb7b41003b416aefbdf821cf4312d15d11f019250`; adress https://publik.hv-sog.se/oden/maps/sverige-raster-20261120.pmtiles (den äldre `sverige-raster.pmtiles`, SHA256 `85659a9e…`, 2 250 443 850 byte, finns kvar för äldre ISO-filer) adress i `.env` (`ODEN_MAPS_URL`) |
| sweden-osm.pmtiles | OSM 2026-05-20 | Vektorkälla till rastret, medvetet ur `artifacts.lock` |

## Öppna frågor och beslut
- Lösenfrasen har ingen minsta längd (beslut 2026-11-20, för test); `ODEN_MINLEN` kan sätta en. Teckenbegränsningen kvarstår. Krav på lösenfrasens styrka ligger under "Senare" i `KRAVSPEC.md`.
- AI-modeller i `minimal` (hämtas inte från nätet än).
- Oden är en "onefile"-binär som packar upp sig själv (ca 200 MB) i `/tmp` (RAM) vid varje start. Alternativ: "onedir".
- Beteendet vid fel lösenfras vid boot (starta utan persistens eller fråga igen) är inte dokumenterat. Skripten förutsätter det förra.
- Obsidian-pluginernas version mot Obsidian 1.15.1.
- GitHub tillåter högst 2 GiB per fil i en release, så ISO-filerna ligger på `publik.hv-sog.se` (Cloudflare R2, bucketen `public-hv-sog`).

## Nästa steg
1. Provstarta `karta-ai` på en sticka (minst 32 GB) och kontrollera att Ollama laddar modellerna.
2. Dokumentera testresultaten: `HW-MATRIS.md` (minst fyra datorer, med och utan Secure Boot), paketfångst, strömavbrott och `oden-wipe`.
3. Statusindikator för frånkopplat läge (steg 04).
4. Bygge utan vår infrastruktur: se `plan/10-oberoende-bygge.md`.

## Publicera en ny ISO
1. `ODEN_VARIANTS=<variant> ./build/build.sh` (se `ADMINGUIDE.md`).
2. Ladda upp `oden-<variant>-<version>.iso`, `.sha256` och `SBOM.txt` till `public-hv-sog/oden/<version>/` och kontrollera filerna mot de lokala.
3. `build/scripts/release-json.sh https://publik.hv-sog.se/oden/<version> > site/releases.json`, committa och pusha.
