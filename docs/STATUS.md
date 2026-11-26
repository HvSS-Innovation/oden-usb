# Status: ODEN-stick

Uppdaterad 2026-11-26. Allt ligger på `main` (grenen `feature/stick-bygge` är sammanslagen). Vad som hämtas in och varifrån: se [`KALLOR.md`](KALLOR.md).

## Läge i korthet
- Bygg-pipelinen är klar: artefakterna är låsta, Oden för Linux byggs i en Debian 13-container och bilden byggs med live-build (Debian 13, XFCE).
- Systemet är testat på stickor (uppgift från Nicklas, 2026-11-20): start, krypterad persistens, upplåsning vid boot, Oden, Obsidian och den lokala kartan i Map View.
  Resultaten är inte dokumenterade i detalj; maskinvarumatrisen (`HW-MATRIS.md`) är ännu tom.
- Kartan är klar: rasterkartan `sverige-raster-20261120.pmtiles` (zoom 0–14, 1 914 774 924 byte, OSM 2026-11-20) är renderad och uppladdad till R2 (`oden/maps/`). Adress: <https://publik.hv-sog.se/oden/maps/sverige-raster-20261120.pmtiles> (sätts som `ODEN_MAPS_URL` i `.env`). Lokalt och på ISO:n heter filen `sverige.pmtiles` (Map View och kartservern förutsätter namnet).
  `MAP_MAXZOOM=14` i `build/map.conf`.
- ISO-varianterna är publicerade 2026-11-26 på `https://publik.hv-sog.se/oden/4bcf96a/` (alla tre byggda från committen 4bcf96a; `minimal` och `karta-ai` med samma xorriso-steg som `build.sh` på samma `oden.iso`). Äldre omgångar (a7a6a2a, f1f80df) är raderade från R2. **Inte provstartade på riktig maskin** (usb-watch provad i VM; skärmlåset, wifi-persistens, skrivare och batteriplugin har bara stubb- och containertest). Innehåll: Oden 4.3.0 (onedir), `wpasupplicant`, `oden-wifi` (guide, dolda nät, `oden-wifi fil`), wifi-nät sparas på lagringen (`oden-nm-persist`), skrivare (CUPS, `system-config-printer`, IP/USB via `oden-admin` 8, sparas), ingen *Logga ut*, skärmlås som öppnas med krypteringslösenordet (*Lås nu*, tid 1 min–1 h), avstängning när stickan dras ur och RAM-förladdning (`oden-usb-watch`, `oden-ramcache`), skrivbordsgenvägar och egna ikoner, batteriplugin i panelen, skärmskala (`oden-scale`). SHA256 kontrollerad mot publika adressen.
  - **karta**: `oden-karta-4bcf96a.iso`, 5 666 242 560 byte, SHA256 `b26b9cfa…63b0`.
  - **minimal**: `oden-minimal-4bcf96a.iso`, 3 751 477 248 byte, SHA256 `fe8ac78e…09a3`. Hämtar kartan vid första start från adressen i `assets.lock` i ISO-filen.
  - **karta-ai**: `oden-karta-ai-4bcf96a.iso`, 14 228 324 352 byte, SHA256 `dfc2746f…efe4`.
- Sajten (GitHub Pages, https://hvss-innovation.github.io/oden-usb/) publiceras från `site/` vid push till `main`. Pages-jobbet kan ibland falla på ett tillfälligt artefaktfel; kör då om jobbet.

## Per steg (se `plan/arkiv/`)
| Steg | Status | Detaljer |
|---|---|---|
| 00 Beslut och kravspec | Klart | `KRAVSPEC.md`, hotmodell beslutad |
| 01 Bygg-pipeline | Klart | `build.sh`, `fetch.sh`, artefaktlås, SBOM, `bump.sh`, `make-stick.sh`, `tests/run.sh`. Förkontrollen av `maps.lock` i `build.sh` ignorerar nu kommentarsrader |
| 02 Mjukvara i bilden | Klart | Oden (versionen stämplas ur `artifacts.lock`), signal-cli, JRE, ODEN-valv, Obsidian (valvet registrerat, community-plugins på), go-pmtiles. Det finns ingen kod för `config.ini`-förkonfiguration eller `--no-sandbox` i bygget |
| 03 Krypterad persistens | Klart | `oden-firstboot`, `oden-wipe`, `oden-persist-dev`, `oden-persist-state`, `oden-passphrase-ok` (a-z, A-Z, 0-9 och mellanslag, ingen minsta längd), LUKS-etikett `oden-pending` → `oden` som sista steg |
| 04 Nät, Signal, TAK | Delvis | NetworkManager, nftables, timesyncd och wifi-firmware ingår (från och med nästa bygge även `broadcom-sta-dkms` för Broadcom BCM4360 i MacBook Pro 2013/2014). Signal-länkning och TAK sköts av Odens eget gränssnitt. Tydlig statusindikator för frånkopplat läge finns inte |
| 05 Kartor | Klart | Raster z0–14 renderat och låst. Map View använder bara den lokala kartan (`stage.sh`, `build/map.conf`) och är provad i Obsidian |
| 06 AI / Ollama | Delvis | `ollama.service`, RAM-kontroll (16 GB) och NVIDIA-paket finns. Modellerna (`qwen3-vl:4b`, `qwen3:8b`, 8 GB) ligger i `build/cache/assets/ollama/` och ingår i `karta-ai`. Rudimentärt provad; en fullständig provkörning på en sticka återstår |
| 07 Test, härdning, dokumentation | Delvis | Användarguide, adminguide, felsökning och HW-mall är skrivna. Kvar att dokumentera: maskinvarumatris, paketfångst, strömavbrott och `oden-wipe` |
| 08 ISO-varianter (Etcher) | Delvis | `karta`, `minimal` och `karta-ai` byggda och publicerade (`karta-ai` rudimentärt provad). AI-modeller i `minimal` är inte gjorda; `karta-ai` täcker AI |
| 09 ODEN-utseende | Klart | GRUB-tema, Plymouth, bakgrund, inloggning, genvägar, högupplöst skärm och pekplatta |

## Artefakter (`build/artifacts.lock`)
| Artefakt | Version | Status |
|---|---|---|
| Oden (byggd, onedir) | 4.3.0, commit cfc6b4a6 (publicerad i 4bcf96a) | Byggd lokalt, ej bit-för-bit reproducerbar (pip `>=`) |
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
- Oden byggs som onedir (`/opt/oden/oden` + `_internal/`, Oden PR #304) och packar inte upp något i `/tmp` vid start. Provad i qemu på `karta`.
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
