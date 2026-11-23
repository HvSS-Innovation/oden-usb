# Adminguide: bygga och skriva ODEN-stickor

> Underliggande projekt och var de hämtas: se [`KALLOR.md`](KALLOR.md).

## Översikt: vad som finns var
```
build/
  artifacts.lock        låsta artefakter: namn, URL, SHA256, # versionsinfo
  sources.conf          var varje artefakt kommer ifrån (GitHub-repo, taggmall, asset-mönster)
  build.sh              fetch -> verifiera -> bygg Oden -> staging -> live-build -> out/oden.iso + SBOM
  fetch.sh              hämtar och verifierar artefakter
  scripts/bump.sh       uppgradera en artefakt i lås-filen
  scripts/build-oden.sh bygger Oden för Linux från källa (docker, PyInstaller)
  scripts/stage.sh      packar upp artefakter i bilden under /opt och skriver /etc/oden-release
  scripts/make-stick.sh skriver bilden till en USB-stick och lägger till assets-partitionen och p4
  config/ overlay/      live-build-konfig och filer som kopieras in i bilden
  tests/run.sh          offline-tester av skripten
```
Cache och byggresultat (`build/cache/`, `build/out/`) ligger utanför git.

## Krav på byggmaskinen
Linux med docker, GitHub CLI (`gh`, inloggad), `python3`, `curl`, `tar`, `zstd` (Ollama-arkivet), `gdisk` (sgdisk),
`fdisk` (sfdisk), `e2fsprogs`, `parted`. Byggmaskinen behöver nät: `fetch.sh`, `bump.sh`, `build-oden.sh` (pip), `docker build` och live-build (debootstrap/apt mot Debians speglar).
Bara den färdiga stickan ska gå att köra offline, inte byggprocessen.

## Bygga en ny stick från noll
```
./build/tests/run.sh                 # 1. snabb kontroll av skripten (offline)
./build/build.sh                     # 2. hämta, verifiera, bygg Oden, bygg bilden -> build/out/oden.iso
# Valfria ISO-varianter för Etcher (kräver ODEN_ASSETS med maps/ och ollama/, och ODEN_MAPS_URL (.env) för minimal):
#   ODEN_VARIANTS=minimal,karta,karta-ai ./build/build.sh     # -> build/out/oden-<variant>-<version>.iso + .sha256
# Publicera: ladda upp ISO-filen, .sha256 och SBOM.txt till bucketen public-hv-sog (Cloudflare R2, nås på https://publik.hv-sog.se/),
#   under oden/<version>/ (GitHub tillåter max 2 GiB per fil, så ISO-filerna ligger inte där). Sedan:
#   build/scripts/release-json.sh https://publik.hv-sog.se/oden/<version> > site/releases.json   # och committa; Pages-sidan Ladda ner visar länkar och SHA256
ls build/cache/assets/maps           # 3. lägg assets: maps/ (krävs), ollama/ (bara för --with-ai)
sudo ./build/scripts/make-stick.sh [--with-ai] build/out/oden.iso /dev/sdX     # 4. skriv stickan
```
- `build.sh --no-fetch` hoppar bara över `fetch.sh`; artefakterna måste redan ligga i `cache/`. Bygget behöver ändå nät
  (docker, live-build, och pip om `oden-linux` ska byggas om).
- `make-stick.sh` kräver en flyttbar hel disk på minst 60 GB och frågar innan allt raderas.
- Layout: p1 ISO-data (live), p2 EFI, p3 `oden-assets` (ext4, skrivskyddad på `/srv/oden-assets`), p4 `persistence` (krypteras
  vid första start).
- Spara `build/out/SBOM.txt` tillsammans med stickans versionsstämpel (`/etc/oden-release` i bilden).
- Test på en riktig stick: se `plan/arkiv/07-test-harda-dokumentera.md` och fyll i `docs/HW-MATRIS.md`.

## Felsökning på stickan
`oden-admin` (`build/overlay/usr/local/bin/oden-admin`, ikon på skrivbordet) är en meny för nätverk, tjänster, versioner och maskinvara, och `oden-admin rapport` samlar allt i en fil. Det går också att köra delarna direkt: `status`, `nat`, `nattest`, `tjanster`, `versioner`, `hw`. Versionslistan läser `/etc/oden-versions` och `/etc/oden-release`, som `stage.sh` skriver vid bygget.

## Uppgradera ett verktyg
Alla versioner står i `artifacts.lock`. Uppgradering är alltid samma tre steg: bumpa, granska, bygg om.
```
./build/scripts/bump.sh --list                    # vilka artefakter finns
./build/scripts/bump.sh go-pmtiles 1.32.0         # en specifik version
./build/scripts/bump.sh ollama latest             # senaste release
git diff build/artifacts.lock                     # granska: URL, SHA256 och versionskommentar
./build/tests/run.sh && ./build/build.sh          # bygg en ny bild; skriv sedan en ny stick
```
| Artefakt | Exempel | Att kontrollera efter uppgradering |
|---|---|---|
| `oden-source` | `bump.sh oden-source 4.3.0` | Byggs om automatiskt (`cache/oden-linux` raderas). Kontrollera att Oden startar och att `oden.service` stämmer med binärens namn; läs upstreams CHANGELOG. |
| `oden-valv` | `bump.sh oden-valv 1.7.0` | Valv och plugin ska vara kompatibla med vald Obsidian-version. Map View ska peka på `127.0.0.1:8081` (steg 05). |
| `signal-cli` | `bump.sh signal-cli 0.14.6` | Bundlas in i Oden-binären (bygger om). Matcha mot den Java-version Oden-repot kräver. |
| `jre-x64` | `bump.sh jre-x64 25.0.6.1+1` | Bundlas in i Oden-binären (bygger om). Versionen är Temurins tagg utan `jdk-`. |
| `obsidian-appimage` | `bump.sh obsidian-appimage 1.16.0` | Obsidian ska starta med valvet och Map View-pluginen. |
| `go-pmtiles` | `bump.sh go-pmtiles 1.32.0` | Kontrollera flaggsyntaxen för `serve` (se `pmtiles.service`). |
| `ollama` | `bump.sh ollama latest` | Kontrollera att modellerna i `ollama/` fortfarande laddas. Arkivet är ca 1,5 GB. |

Andra uppgraderingar:
- **Debian-paket** kommer från live-build vid varje bygge (trixie). Paketlistorna ligger i `config/config/package-lists/`;
  `SBOM.txt` visar vilka versioner som ingick.
- **Ny artefakt eller ny källa:** lägg en rad i `sources.conf` och en rad i `artifacts.lock`
  (`<namn> PENDING_URL PENDING`), kör sedan `bump.sh <namn> latest`. Lägg uppackning i `stage.sh` och en kontroll av
  binären i dess slutkontroll, och ett testfall i `tests/run.sh`.
- **Ny karta eller nya modeller:** ersätt filerna i `build/cache/assets/` och skriv en ny stick.
- **`bump.sh` ger "N asset matchar":** upstream har bytt filnamn. Justera regexet i `sources.conf`.

## Om Oden för Linux
Upstream släpper bara Windows och macOS. `build-oden.sh` bygger Linux-binären från git-taggen med upstreams egen
`s7_watcher.spec` (en enda körbar fil med JRE och signal-cli inbyggda) i `python:3.12-bookworm`. Resultatet är
`build/cache/oden-linux` (ca 200 MB). Radera filen för att bygga om. SBOM:en innehåller binärens SHA256 och
`pip freeze`.

## Kända begränsningar
- **`oden-linux` är inte bit-för-bit reproducerbar.** Python-beroendena i Oden är angivna som `>=`, så pip kan välja
  nyare versioner vid ett senare bygge. `cache/oden-linux.pip-freeze.txt` och SBOM:en dokumenterar vad som ingick.
- GitHubs källtarball för en tagg har normalt samma checksumma över tid, men det garanteras inte. Avviker den
  misslyckas bygget (avsiktligt): kontrollera commit-hashen i kommentaren på raden och kör `bump.sh oden-source <version>` igen.
- Oden-binären är "onefile": den packar upp sig själv (ca 200 MB) i `/tmp` vid varje start. På stickan är `/tmp` RAM.
- `sweden-osm.pmtiles` (vektor, 4 GB) ligger medvetet utanför `artifacts.lock` och används inte av bilden; kartan i bilden är
  den renderade rasterfilen (steg 05), adress i `ODEN_MAPS_URL` (`.env`). Lokalt måste den heta `build/cache/assets/maps/sverige.pmtiles` (även om adressen har ett datum i namnet), annars avbryter `build.sh`.
- Obsidian körs som extraherad AppImage. Bygget sätter inte `--no-sandbox`.
- Ollama-modeller har inget versionslås.
- **Debian-paketen i bilden är medvetet inte pinnade.** live-build hämtar aktuella paket från Debians speglar vid varje
  bygge, och `artifacts.lock` täcker dem inte. Releasen är den färdiga ISO:n, inte byggreceptet: behövs ett nytt bygge
  blir det en ny release. `build/out/SBOM.txt` listar vilka paketversioner som ingick i just den ISO:n.

## Nycklar
Varje stick får egen LUKS-nyckel vid första start; det finns ingen central nyckel och ingen header-backup.
Förlorad lösenfras = förlorad data. Vid förlorad stick: koppla bort stickans enhet i Signal och spärra dess TAK-certifikat.

## Version
`/etc/oden-release` i bilden innehåller bygg-datum och checksumma för `artifacts.lock`. Versionerna för varje verktyg
står som kommentar på respektive rad i `artifacts.lock`.
