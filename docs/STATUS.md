# Status: ODEN-stick

Uppdaterad 2026-11-20: allt är testat (uppgift från Nicklas). Resten av dokumentet är skrivet 2026-11-19, före testerna. Rader som säger "ej provat", "skrivet" eller "kvar" är därför överspelade och ska skrivas om när testresultaten är dokumenterade.

## Läge i korthet
- Bygg-pipelinen är på plats och alla artefakter är låsta. Oden för Linux bygger och startar i en Debian 13-container.
- Bilden har byggts med live-build och har exakt 2 GPT-partitioner (p1 ISO, p2 EFI, kontrollerat med sfdisk/sgdisk). Den är **inte bootad**.
  `make-stick.sh`, krypterad persistens, upplåsning vid boot och de nya Etcher-varianterna är **inte körda på en stick**. Det är nästa stora risk.
- Målet är nu tre ISO-filer (minimal, karta, karta+AI) som går att bränna med Etcher (se `plan/08-iso-varianter.md`). All kod finns, men bara testad mot filavbilder och fejkade verktyg.
- Fynden i granskningen 2026-11-19 (tio) är åtgärdade i koden, flera overifierade (se `docs/GRANSKNING-2026-11-19.md`).
- Kartan (rasterrendering) är inte gjord och inte uppladdad, och utan den visar stickan ingen karta. `build/maps.lock` är tom, så `minimal` kan inte byggas än.
- GitHub Pages-skal finns i `site/` (publiceras från `main`; kräver att Pages sätts till *GitHub Actions*).

## Per steg (se `plan/`)
| Steg | Status | Detaljer |
|---|---|---|
| 00 Beslut och kravspec | Klart | `docs/KRAVSPEC.md`, hotmodell beslutad |
| 01 Bygg-pipeline | Skrivet | `build.sh`, `fetch.sh`, låsning, SBOM, `bump.sh`, `make-stick.sh`. Testat: syntax, partitionering på gles fil, `tests/run.sh`. Ej testat: live-build-bygget, `dd`/`mkfs`/`mount` mot en enhet, att live-builds iso-hybrid-ISO (efterbehandlad till GPT med p1 ISO-data + p2 EFI) har exakt 2 partitioner. Verifierat med sfdisk, ej bootat |
| 02 Mjukvara i bilden | Delvis klart | Oden-binär byggd (`/opt/oden/oden`, 197 MB) och rökprovad; `stage.sh` testad mot riktiga artefakter. Kvar: `config.ini`- och Obsidian-förkonfiguration, `--no-sandbox` för Obsidian, versionsnummer i binären (visar `v0.0.0-dev`) |
| 03 Krypterad persistens | Skrivet | `oden-firstboot`, `oden-wipe`, `oden-persist-dev`, `oden-persist-state`, `oden-passphrase-ok` (enbart a-z, 0-9, mellanslag, minst 16 tecken), LUKS-etikett `oden-pending` → `oden` som sista steg. Syntax och lösenfrastester körda; cryptsetup-flödet inte. Ej verifierat: `--label`/`config --label`/luksDump-parsning, live-boots upplåsning med frasen, beteende vid fel fras, `noatime`, strömavbrottstest |
| 04 Nät, Signal, TAK | Delvis | NetworkManager, nftables, timesyncd och wifi-firmware finns i bilden (ej provade). Kvar: tydlig statusindikator för frånkopplat läge. Signal-länkning och TAK sköts av Odens eget gränssnitt (ej provat i bilden) |
| 05 Kartor | Delvis | Renderingsskript klart (`build/scripts/map/render-map.sh`, guide i `docs/KARTRENDERING.md`) och provat mot fjärrfilen. PoC z0–12 renderas lokalt; z14 ska köras på annan maskin. Map View använder bara den lokala kartan (`stage.sh`, `build/map.conf`). `pmtiles serve`-flaggorna kontrollerade mot v1.31.2. Ej provat i Obsidian på hårdvara |
| 06 AI / Ollama | Skrivet | `ollama.service`, RAM-kontroll, NVIDIA-paket i paketlistan, Ollama låst. Modeller (`qwen3-vl:4b`, `qwen3:8b`) är inte hämtade. Inget provat |
| 08 ISO-varianter (Etcher) | Skrivet | `oden-make-persist` (skapar partitioner efter ISO-datan, `sgdisk -e`/`partx -a`), `oden-assets-bind` (+ `oden-assets.service`), `oden-fetch-assets` (kartor vid första start), `ODEN_VARIANTS` i `build.sh`, `release-json.sh`, `site/ladda-ner.html`. Testat: filavbilder, fejkad mount/curl, xorriso i Docker med 4,3 GB-fil. Ej provat: allt på en riktig stick (partx live, mount av fil >4 GiB, bind-montering, nedladdning) |
| 09 ODEN-utseende | Skrivet | Högupplöst skärm (skala 1/2) och Mac-vänlig pekplatta. GRUB-tema med Odens logga och svenska menyer, skrivbordsbakgrund, inloggningsbild, genvägar. Plymouth-tema (uppstartsbild) tillagt. Ej provat på hårdvara (`plan/09-oden-utseende.md`) |
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
- Lösenfrasen har ingen minsta längd (beslut 2026-11-20, för test); `ODEN_MINLEN` kan sätta en. Teckenbegränsningen kvarstår. `KRAVSPEC` listar lösenfrasstyrka under "Senare".
- AI-modeller i `minimal` (hämtas inte från nätet än; `karta-ai` täcker AI).
- Oden är en "onefile"-binär som packar upp sig själv (ca 200 MB) i `/tmp` (RAM) vid varje start. Alternativ: bygga "onedir".
- Oden kan öppna webbläsaren själv vid första start (`_welcome_first_start`), och stickan autostartar också en webbläsare. Ej provat.
- Oden-GUI lyssnar på `127.0.0.1:8080` enligt planen, men att inga andra portar är öppna (`ss -tulpn`) är inte kontrollerat.
- Fel lösenfras vid boot: live-boot kan starta utan persistens eller upprepa frågan. Ej verifierat; skripten förutsätter det förra.
- Hård strömavstängning och SQLite WAL i Oden är inte undersökt.
- Obsidian-pluginernas version mot Obsidian 1.15.1 är inte kontrollerad.

## Nästa steg i ordning
1. **Första stickprovet** (provlista nedan) med `minimal`-lik bas: bränn `build/out/oden.iso` med Etcher (basbilden duger för att prova partitionering, firstboot och upplåsning; kartor kommer senare).
2. Rendera rasterkartan (steg 05), ladda upp den, fyll i `build/maps.lock` och `build/cache/assets/maps/`. Bygg varianterna: `ODEN_VARIANTS=all ./build/build.sh`.
3. Prova `karta` (fil över 4 GiB, bind-montering) och `minimal` (nedladdning) på stick.
4. Förkonfigurera Oden och Obsidian (steg 02, uppgift 7) och koppla kartan i Map View.
5. Maskinvarumatris, paketfångst, strömavbrott och E2E (steg 07).
6. Pusha grenen, ställ in Pages, ladda upp ISO-filer och fyll `site/releases.json` med `release-json.sh`.

## Provlista för första stickprovet
Bränn `build/out/oden.iso` (basbilden) på en tom 64 GB-stickan med Etcher. Ha en terminal öppen (Ctrl+Alt+T eller via menyn). Notera allt som avviker.
1. Startar stickan (UEFI, utan Secure Boot först)? Kommer skrivbordet upp?
2. `lsblk -o NAME,SIZE,PARTLABEL,FSTYPE` och `findmnt /run/live/medium`: ligger mediet där? Finns bara p1/p2 före första start?
3. Kommer fråga om lösenfras? Prova först en med å/ä/ö (ska avvisas), en kort (ska avvisas), sedan en giltig.
4. Efter luksFormat: `lsblk` visar ny partition `persistence`? (Fel: se felsökning, "Ingen persistens".) `sudo cryptsetup luksDump <part> | grep Label` ska ge `oden`.
5. Efter omstart: frågar live-boot efter lösenfras? Fungerar den? Startar Oden och Obsidian? Finns `~/.oden-persist`?
6. Fel lösenfras vid boot: vad händer (startar utan persistens, eller frågar igen)? Notera.
7. `oden-wipe`: går data att öppna efteråt? (Förstör stickans data.) Avbrott: dra ur stickan mitt under firstboot och starta igen (ska erbjuda göra om).
8. `ss -tulpn`: bara `127.0.0.1:8080` m.fl. lokala portar lyssnar?
9. Notera stickans storlek och hur lång tid Etcher tog (för guiden).

## Commits på grenen (sedan `main`)
Plan, Steg 00–01, Steg 02 (konfig), Steg 03, `make-stick.sh`, staging, steg 07-dokument, bygg av Oden och `bump.sh`,
adminguide. Se `git log main..feature/stick-bygge`.
