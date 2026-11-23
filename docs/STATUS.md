# Status: ODEN-stick

Uppdaterad 2026-11-22. Allt ligger på `main` (grenen `feature/stick-bygge` är sammanslagen). Vad som hämtas in och varifrån: se [`KALLOR.md`](KALLOR.md).

## Läge i korthet
- Bygg-pipelinen är klar: artefakterna är låsta, Oden för Linux byggs i en Debian 13-container och bilden byggs med live-build (Debian 13, XFCE).
- Systemet är testat på stickor (uppgift från Nicklas, 2026-11-20): start, krypterad persistens, upplåsning vid boot, Oden, Obsidian och den lokala kartan i Map View.
  Resultaten är inte dokumenterade i detalj; maskinvarumatrisen (`HW-MATRIS.md`) är ännu tom.
- Kartan är klar: rasterkartan `sverige-raster-20261120.pmtiles` (zoom 0–14, 1 914 774 924 byte, OSM 2026-11-20) är renderad och uppladdad till R2 (`oden/maps/`). Adress: <https://publik.hv-sog.se/oden/maps/sverige-raster-20261120.pmtiles> (sätts som `ODEN_MAPS_URL` i `.env`). Lokalt och på ISO:n heter filen `sverige.pmtiles` (Map View och kartservern förutsätter namnet).
  `MAP_MAXZOOM=14` i `build/map.conf`.
- ISO-varianterna är ombyggda och publicerade på `https://publik.hv-sog.se/oden/4012904/`, med kontrollsumma och SBOM (kontrollerade mot de lokala filerna efter uppladdning). De tidigare filerna (`b81c7d6`) hade en karta som inte visades: Map View pekar på `/sverige/…` men kartfilen hette `sverige-raster-20261120.pmtiles`. Nu heter den lokalt `sverige.pmtiles`, och `build.sh` avbryter om namnet är fel. Kartan är provad i Obsidian på `karta` (provstartad i qemu utan KVM, med kartservern startad manuellt); `karta-ai` är provad i begränsad omfattning; `minimal` är inte provstartad.
  - **karta**: `oden-karta-4012904.iso`, 5 625 282 560 byte, SHA256 `9eb0508a…f833`.
  - **minimal**: `oden-minimal-4012904.iso`, 3 710 517 248 byte, SHA256 `fd8eab6d…f755`. Hämtar kartan vid första start från adressen i `assets.lock` i ISO-filen.
  - **karta-ai**: `oden-karta-ai-4012904.iso`, 14 187 364 352 byte, SHA256 `708ee6eb…4c75`.
- Sajten (GitHub Pages, https://hvss-innovation.github.io/oden-usb/) publiceras från `site/` vid push till `main`. Pages-jobbet kan ibland falla på ett tillfälligt artefaktfel; kör då om jobbet.

## Per steg (se `plan/arkiv/`)
| Steg | Status | Detaljer |
|---|---|---|
| 00 Beslut och kravspec | Klart | `KRAVSPEC.md`, hotmodell beslutad |
| 01 Bygg-pipeline | Klart | `build.sh`, `fetch.sh`, artefaktlås, SBOM, `bump.sh`, `make-stick.sh`, `tests/run.sh`. Förkontrollen av `maps.lock` i `build.sh` ignorerar nu kommentarsrader |
| 02 Mjukvara i bilden | Klart | Oden (versionen stämplas ur `artifacts.lock`), signal-cli, JRE, ODEN-valv, Obsidian (valvet registrerat, community-plugins på), go-pmtiles. Det finns ingen kod för `config.ini`-förkonfiguration eller `--no-sandbox` i bygget |
| 03 Krypterad persistens | Klart | `oden-firstboot`, `oden-wipe`, `oden-persist-dev`, `oden-persist-state`, `oden-passphrase-ok` (a-z, A-Z, 0-9 och mellanslag, ingen minsta längd), LUKS-etikett `oden-pending` → `oden` som sista steg |
| 04 Nät, Signal, TAK | Delvis | NetworkManager, nftables, timesyncd och wifi-firmware ingår. Signal-länkning och TAK sköts av Odens eget gränssnitt. Tydlig statusindikator för frånkopplat läge finns inte |
| 05 Kartor | Klart | Raster z0–14 renderat och låst. Map View använder bara den lokala kartan (`stage.sh`, `build/map.conf`) och är provad i Obsidian |
| 06 AI / Ollama | Delvis | `ollama.service`, RAM-kontroll (16 GB) och NVIDIA-paket finns. Modellerna (`qwen3-vl:4b`, `qwen3:8b`, 8 GB) ligger i `build/cache/assets/ollama/` och ingår i `karta-ai`. Rudimentärt provad; en fullständig provkörning på en sticka återstår |
| 07 Test, härdning, dokumentation | Delvis | Användarguide, adminguide, felsökning och HW-mall är skrivna. Kvar att dokumentera: maskinvarumatris, paketfångst, strömavbrott och `oden-wipe` |
| 08 ISO-varianter (Etcher) | Delvis | `karta`, `minimal` och `karta-ai` byggda och publicerade (`karta-ai` rudimentärt provad). AI-modeller i `minimal` är inte gjorda; `karta-ai` täcker AI |
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
| sverige-raster-20261120.pmtiles | OSM 2026-11-20, z0–14 | SHA256 `8434482de33755c1b1fdc7fdb7b41003b416aefbdf821cf4312d15d11f019250`; adress https://publik.hv-sog.se/oden/maps/sverige-raster-20261120.pmtiles (den äldre `sverige-raster.pmtiles` är borttagen från R2) adress i `.env` (`ODEN_MAPS_URL`) |
| sweden-osm.pmtiles | OSM 2026-05-20 | Vektorkälla till rastret, medvetet ur `artifacts.lock` |

## Öppna frågor och beslut
- Lösenfrasen har ingen minsta längd (beslut 2026-11-20, för test); `ODEN_MINLEN` kan sätta en. Teckenbegränsningen kvarstår. Krav på lösenfrasens styrka ligger under "Senare" i `KRAVSPEC.md`.
- AI-modeller i `minimal` (hämtas inte från nätet än).
- Oden är en "onefile"-binär som packar upp sig själv (ca 200 MB) i `/tmp` (RAM) vid varje start. Alternativ: "onedir".
- Fel lösenfras vid boot: `oden-firstboot` frågar vid inloggning om användaren vill starta om och skriva lösenfrasen igen eller radera lagringen och börja om med ny lösenfras (RADERA måste skrivas). Finns i källan, ingår i nästa ISO-bygge.
- Obsidian-pluginernas version mot Obsidian 1.15.1.
- GitHub tillåter högst 2 GiB per fil i en release, så ISO-filerna ligger på `publik.hv-sog.se` (Cloudflare R2, bucketen `public-hv-sog`).

## Nästa steg
1. Provkör `karta-ai` fullt ut på en sticka (minst 32 GB; 16 GB räcker för `karta`): Ollama ska ladda modellerna och svara.
2. Dokumentera testresultaten: `HW-MATRIS.md` (minst fyra datorer, med och utan Secure Boot), paketfångst, strömavbrott och `oden-wipe`.
3. Statusindikator för frånkopplat läge (steg 04).


## Publicera en ny ISO
1. `ODEN_VARIANTS=<variant> ./build/build.sh` (se `ADMINGUIDE.md`).
2. Ladda upp `oden-<variant>-<version>.iso`, `.sha256` och `SBOM.txt` till `public-hv-sog/oden/<version>/` och kontrollera filerna mot de lokala.
3. `build/scripts/release-json.sh https://publik.hv-sog.se/oden/<version> > site/releases.json`, committa och pusha.
