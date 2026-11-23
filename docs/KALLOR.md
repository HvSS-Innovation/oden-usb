# Underliggande projekt och källor

ODEN-stickan är en sammansättning av andra projekt. Den här sidan visar vad som hämtas in, var det kommer ifrån och hur det versionslåses.
Versioner och checksummor står i [`build/artifacts.lock`](../build/artifacts.lock) (programvara); kartor: se `ODEN_MAPS_URL`, `build/maps.lock.example`.
Var varje artefakt hämtas ifrån står i [`build/sources.conf`](../build/sources.conf).

## ODEN-projekten

| Projekt | Används till | Källa | Version | Licens |
|---|---|---|---|---|
| **Oden** (Bin 1) | Tar emot Signal-meddelanden och skriver Markdown. Webbgränssnitt på `127.0.0.1:8080`, TAK-stöd | [NicklasAndersson/oden](https://github.com/NicklasAndersson/oden) | v4.2.1 | MIT |
| **ODEN-analys** (Bin 2) | Obsidian-valv och plugin för analys. Innehåller Map View och AI-pluginet | [larsnor/ODEN-analys](https://github.com/larsnor/ODEN-analys) | v1.6.3 | MIT |

- Upstream släpper bara Oden för Windows och macOS. Linux-binären byggs av [`build/scripts/build-oden.sh`](../build/scripts/build-oden.sh) från källkoden med Odens egen `s7_watcher.spec` (PyInstaller), och versionen stämplas ur låset.
- Valvet hämtas som releasefilen `ODEN-valv-<version>.zip` och packas upp som mall som kopieras till `/home` vid första start.

## Det som ingår i Oden-binären

| Projekt | Används till | Källa | Version | Licens |
|---|---|---|---|---|
| **signal-cli** | Signal-klient (länkad enhet) | [AsamK/signal-cli](https://github.com/AsamK/signal-cli) | v0.14.5 | GPL-3.0 |
| **Temurin JRE** | Java som signal-cli kräver | [adoptium/temurin25-binaries](https://github.com/adoptium/temurin25-binaries) | jdk-25.0.5.1+2 | GPLv2 med Classpath Exception |

## Program på stickan

| Projekt | Används till | Källa | Version | Licens |
|---|---|---|---|---|
| **Obsidian** | Läser ODEN-valvet. Körs som extraherad AppImage | [obsidianmd/obsidian-releases](https://github.com/obsidianmd/obsidian-releases) | v1.15.1 | Proprietär, gratis. Distribution i bilden är bekräftad |
| **Map View** (Obsidian-plugin) | Karta i Obsidian. Ingår i ODEN-valvet; bygget byter dess standardkälla mot den lokala kartan | [esm7/obsidian-map-view](https://github.com/esm7/obsidian-map-view) | enligt valvet | MIT |
| **go-pmtiles** | Serverar kartan lokalt som rutor på `127.0.0.1:8081` | [protomaps/go-pmtiles](https://github.com/protomaps/go-pmtiles) | v1.31.2 | BSD-3-Clause |
| **Ollama** | Kör AI-modeller lokalt (valfritt, kräver minst 16 GB RAM) | [ollama/ollama](https://github.com/ollama/ollama) | v0.40.16 | MIT |

## Operativsystem

| Projekt | Används till | Källa |
|---|---|---|
| **Debian 13 "trixie"** | Basen. Paket hämtas vid varje bygge från Debians speglar (`main contrib non-free non-free-firmware`) | [debian.org](https://www.debian.org/) |
| **live-build** | Bygger live-bilden | [live-team.pages.debian.net](https://live-team.pages.debian.net/live-manual/) |
| **live-boot** | Startar live-systemet och sköter krypterad persistens (LUKS2) | Debians paket `live-boot` |
| **XFCE, LightDM, NetworkManager, nftables m.fl.** | Skrivbord, inloggning, nät och brandvägg | Debians paket. Paketlistorna ligger i [`build/config/config/package-lists/`](../build/config/config/package-lists/) |
| **shim-signed, grub-efi-amd64-signed** | Start med Secure Boot (Debians signerade) | Debians paket |
| **NVIDIA-drivrutin (`nvidia-driver`)** | GPU-stöd för AI. Osignerad, laddas inte med Secure Boot på | Debians paket (`non-free`) |

Debian-paketen pinnas inte. Vilka versioner som ingick i en viss ISO står i `SBOM.txt` som ligger bredvid ISO-filen.

## Kartor

| Projekt | Används till | Källa | Licens |
|---|---|---|---|
| **OpenStreetMap** | Kartdata (OSM 2026-05-20) | [openstreetmap.org](https://www.openstreetmap.org/copyright) | ODbL. Attribution: © OpenStreetMap-bidragsgivare |
| **Protomaps Basemap** | Färdig vektorkarta för Sverige (`sweden-osm.pmtiles`, v4.14.8) och kartstil | [protomaps/basemaps](https://github.com/protomaps/basemaps) | se repot |
| **Protomaps basemaps-assets** | Typsnitt och symboler för kartstilen | [protomaps/basemaps-assets](https://github.com/protomaps/basemaps-assets) | se repot |
| **Planetiler** | Byggde vektorkartan (planetiler 0.10.1) | [onthegomap/planetiler](https://github.com/onthegomap/planetiler) | Apache-2.0 |
| **TileServer GL** | Renderade vektorkartan till raster en gång (v5.7.0) | [maptiler/tileserver-gl](https://github.com/maptiler/tileserver-gl) | se repot |

- Vektorkartan (4,1 GB) hämtas inte av bygget. Den renderades en gång till `sverige-raster-20261120.pmtiles` (zoom 0–14, 1,8 GB, WebP, OSM 2026-11-20 ur Protomaps dagsbygge), som är det stickan använder. Så görs det: [`docs/KARTRENDERING.md`](KARTRENDERING.md) och [`plan/arkiv/05-kartor-pmtiles.md`](../plan/arkiv/05-kartor-pmtiles.md).
- Kartadressen för `minimal` kommer ur `ODEN_MAPS_URL` (miljön eller ignorerad `.env`); aktuell fil: <https://publik.hv-sog.se/oden/maps/sverige-raster-20261120.pmtiles>. SHA256 och storlek läses ur rasterfilen i cachen. **Lokalt (i cachen och på ISO:n) heter filen alltid `sverige.pmtiles`**, även om adressen har ett datum i namnet: kartservern och Map View använder namnet (`/sverige/{z}/{x}/{y}.webp`), och `build.sh` avbryter om filen heter något annat.

## AI-modeller (valfritt, `karta-ai`)

| Modell | Används till | Källa |
|---|---|---|
| `qwen3-vl:4b` | Bildanalys | [ollama.com/library/qwen3-vl](https://ollama.com/library/qwen3-vl) |
| `qwen3:8b` | Text, chatt och djupanalys | [ollama.com/library/qwen3](https://ollama.com/library/qwen3) |

Modellerna hämtas med `ollama pull` vid bygget och har inget versionslås.

## Bygg- och publiceringsverktyg

| Verktyg | Används till |
|---|---|
| Docker | Bygger Oden och kör live-build i container |
| xorriso | Skapar ISO-varianterna med kartorna inlagda |
| balenaEtcher ([etcher.balena.io](https://etcher.balena.io/)) | Användarens verktyg för att bränna ISO-filen |
| GitHub Pages | Webbplatsen (`site/`) |
| Cloudflare R2 (`publik.hv-sog.se`) | Lagring och nedladdning av ISO-filerna, som är för stora för GitHub (max 2 GiB per fil) |

## Hur versioner uppgraderas
Alla versioner uppgraderas med [`build/scripts/bump.sh`](../build/scripts/bump.sh): bumpa, granska `git diff build/artifacts.lock`, bygg om. Se [`ADMINGUIDE.md`](ADMINGUIDE.md).
