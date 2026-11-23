# Steg 01: Bygg-pipeline och artefaktlås

**Leverans:** `build/` som med ett kommando ger en bild, och `make-stick.sh` som skriver en färdig stick.

## Struktur
```
build/
  build.sh               # orkestrering: fetch -> verify -> live-build -> image
  artifacts.lock         # URL, version, SHA256 för varje extern artefakt (ej Ollama-modeller)
  fetch.sh               # hämtar allt (enda steget som behöver nät)
  config/                # live-build: package-lists, hooks, includes.chroot
  overlay/               # filer som kopieras in i bilden (systemd-units, skript, config)
  scripts/make-stick.sh  # skriver bild (p1+p2), skapar p3 assets och tom p4
```

## Artefakter (`artifacts.lock`)
| Artefakt | Källa | Notering |
|---|---|---|
| Debian-paket | Debian-spegel | Via live-build |
| Oden (Linux, PyInstaller) | NicklasAndersson/oden | Release-binär om den finns, annars byggd i containern med `s7_watcher.spec` |
| signal-cli 0.14.5 + Temurin JRE 25 | AsamK/signal-cli, Adoptium | Bundlas in i Oden-binären (`signal-cli/`, `jre-x64/`) |
| ODEN-valv + plugin | larsnor/ODEN-analys release (`ODEN-valv-<v>.zip`) | Innehåller Map View |
| Obsidian | obsidian.md AppImage | Licens ok för distribution i bilden |
| go-pmtiles | protomaps/go-pmtiles release | Statisk Go-binär |
| Ollama-binär | ollama.com | Steg 06 |
| NVIDIA-drivrutin | Debian non-free (`nvidia-driver`, `firmware-misc-nonfree`) | Modulen byggs med DKMS mot bildens kärna vid bygget (kräver `linux-headers`) |
| PMTiles-karta (raster) | Renderad en gång från `sweden-osm.pmtiles` (Protomaps-vektor, steg 05) | Läggs på p3 |
| Ollama-modeller | `ollama pull` vid bygget | Inget versionslås |

## make-stick.sh
1. Skriver bilden (p1 ISO-data + p2 EFI).
2. Lägger till p3 (ext4, label `oden-assets`) och kopierar in karta och ev. modeller (`--with-ai`).
3. Lägger till p4 som tar resten av stickan, oformaterad. Den krypteras vid första start (steg 03).

## Regler
- Bygget kräver nät (fetch.sh, docker build, live-build mot Debians speglar, pip för `oden-linux`); bara den färdiga stickan ska fungera offline.
  `build.sh --no-fetch` hoppar över `fetch.sh` när cache/ redan är komplett. Bygget misslyckas om en artefakts checksumma avviker.
- Debian-paketen pinnas medvetet inte: releasen är den färdiga ISO:n, och ett nytt bygge är en ny release. SBOM:en dokumenterar vad som ingick.
- Bygget skriver en SBOM (paket + artefaktversioner) till `build/out/SBOM.txt`.
- Bygg i container (podman/docker).

## Klart när
- `./build/build.sh` på ren maskin ger en bild, och `make-stick.sh` ger en stick.
- Bilden bootar i QEMU/OVMF (`qemu-system-x86_64 -bios OVMF.fd -drive file=oden.iso,format=raw`).

## Status make-stick.sh
Förkontroller före skrivning: flyttbar hel disk, >= 60 GB, bilden har exakt 2 partitioner, `maps/` finns
(och `ollama/` med `--with-ai`) under `$ODEN_ASSETS` (standard `build/cache/assets`). Därefter: `sgdisk --zap-all`,
`dd`, GPT (konverterar MBR vid behov), p2 (EFI) sätts till EF00, p3 `oden-assets` (ext4, innehåll + 5 % + 256 MiB),
p4 `persistence` (resten, första 16 MiB nollade så att gammal LUKS-header inte blir kvar).
Kontrollerat: syntax, sgdisk-sekvensen på en gles fil och partitionstabellen. Bilden är bootad och testad på stickor (Nicklas, 2026-11-20).
(Partitionstabellen: : p1 ISO-data + p2 EFI; `build.sh` efterbehandlar live-builds iso-hybrid med xorriso eftersom grub-efi ensam inte ger MBR/GPT).
p3 monteras skrivskyddat på `/srv/oden-assets` via `build/overlay/etc/fstab` (`nofail`).
