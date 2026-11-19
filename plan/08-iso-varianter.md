# Steg 08: ISO-varianter som går att bränna med Etcher

## Mål
Stickan ska gå att göra med ett vanligt brännprogram (balenaEtcher m.fl.) utan `make-stick.sh`.
Tre ISO-filer ur samma bygge, distribuerade via GitHub Pages (länkar och checksummor) med filerna på S3 eller Google Drive.
Bygget görs lokalt eller på server; GitHub Actions behövs inte för det (får gärna användas för Pages och för checksummor).

| Variant | I ISO-filen | Vid första start |
|---|---|---|
| `minimal` | system och program | skapar p4 (persistens), hämtar karta (och valfritt AI-modeller) från nätet |
| `karta` | + `maps/` | skapar p4 |
| `karta-ai` | + `maps/` och `ollama/` | skapar p4 |

Offlinelöftet gäller stickan i bruk. Nedladdningen i `minimal` är ett engångsmoment vid första start.

## Ny layout (efter Etcher)
```
p1  ISO-data   live-ISO (+ maps/ och ollama/ i de stora varianterna), skrivskyddad
p2  EFI
p3  Assets     bara i minimal: ext4, okrypterad, skapas av firstboot och fylls via nedladdning
p4  Persistence  resten, LUKS2 (som idag)
```
Etcher skriver bara ISO-storleken; resten av stickan är oallokerad. `oden-firstboot` skapar p3/p4 där.
`make-stick.sh` blir en alternativ väg för dem som vill ha karta på separat partition; den tas inte bort.

## Uppgifter
1. **Partitionstabell (klar på pappret, återstår att prova på riktig sticka).** Undersökt på `build/out/oden.iso`: `build.sh` ger redan
   en GPT-hybrid med p1 = ISO9660 och p2 = EFI, och GPT-namn fungerar alltså. Inget behöver ändras i ISO-bygget.
   Efter Etcher ligger sikthuvudet (backup-GPT) vid ISO:ns slut och resten av stickan är oallokerad. Firstboot behöver:
   ```
   sgdisk -e DISK                                   # flytta sikthuvudet till diskens slut
   sgdisk -a 2048 -n 3:0:0 -t 3:8309 -c 3:persistence DISK
   partx -a -n 3 DISK                               # läs in nya partitionen; BLKRRPART/partprobe misslyckas när p1 är monterad
   ```
   Provat på en 64 GB-kopia av ISO:n (fil): `sgdisk -v` ger inga fel, p1/p2 är orörda och p3 (`persistence`) tar resten.
   Utan `-a 2048` hamnar p3 på sektor 7393284, som inte är 4 KiB-justerad; med flaggan startar den på 7395328.
   **Numrering:** en Etcher-bränd sticka får persistensen som **p3** (inte p4). I `minimal` hamnar assets därför före den
   (assets = p3, persistens = p4 om assets skapas först) eller så sparas nedladdat på persistensen. Alla skript hittar persistensen
   via GPT-namnet, så de påverkas inte, men kommentarer och texter som säger "p4" ska rättas.
   **Kvarstår att prova:** att `partx -a` fungerar när stickan körs live, att live-boot hittar `persistence` efter omstart, och att
   Etcher inte rör tabellen. Kan inte provas utan riktig sticka och root.
2. **`oden-firstboot`**: om p4 saknas, skapa den i det lediga utrymmet efter ISO-datan (och p3 i `minimal`).
   Avbrottssäker som idag (LUKS-etikett `oden-pending`). Kräv minsta ledigt utrymme och säg tydligt om det inte räcker.
   **Gjort:** `oden-make-persist` (sgdisk -e, ny partition, `partx -a`, kräver 8 GiB ledigt, idempotent) anropas av `oden-firstboot` när
   ingen persistens-partition finns. Testat mot filavbild i `tests/run.sh`; `partx` och live-beteendet är oprovade. `minimal` (assets som egen partition) återstår.
3. **Sökvägen `/srv/oden-assets`**: i `karta`/`karta-ai` bind-montera `/run/live/medium/maps` (och `ollama`), i `minimal` p3.
   Tjänsterna (`pmtiles.service`, Ollama) ska inte behöva ändras.
   **Gjort:** `oden-assets-bind` + `oden-assets.service` (system, aktiverad i hooken) bind-monterar `maps`/`ollama` skrivskyddat från
   `/run/live/medium` om ingen assets-partition är monterad. Fstab-raden för `LABEL=oden-assets` (p3, `nofail`) är kvar och gäller `minimal` och
   `make-stick.sh`. Testat mot fejkad mount; oprovat live (att mediet ligger på `/run/live/medium` i en ISO-hybrid-boot och att enheten körs före användarsessionen).
4. **Nedladdning i `minimal`** (`oden-fetch-assets`): hämta från S3-URL med SHA256 från en fil i ISO:n, återupptagning (`curl -C -`),
   förloppsvisning, kontroll av ledigt utrymme före start, och hantering av nätfel. Karta 10–25 GB: ge användaren val (hämta nu/senare).
   **Gjort (kartor):** `oden-fetch-assets` läser `/usr/share/oden/assets.lock` (rader: `sökväg url sha256 byte`; filen läggs bara i
   `minimal` av bygget, uppgift 5). Fråga "Hämta nu / Senare", förlopp i zenity, `curl -C -` (återupptar), kontroll av storlek och SHA256,
   `.part`-fil som döps om först när allt stämmer, därefter skrivskyddad montering och omstart av `pmtiles.service`. Autostart först när
   persistensen är klar. **Ordning:** `oden-make-persist` skapar assets-partitionen (`oden-assets`, storlek = summan av byte + 5 % + 256 MiB)
   *före* persistensen, som får resten; annars hade persistensen tagit allt utrymme. Testat med fejkad curl och filavbild.
   **Inte gjort:** AI-modeller i `minimal` (kräver `ollama pull` mot ett körande Ollama, inte en vanlig fil); `karta-ai` täcker behovet tills vidare.
   Oprovat: riktig nedladdning, `partx`/mkfs/mount på stickan, `x-systemd`-montering av nytillkommen partition (görs i skriptet, inte via fstab).
5. **Bygget**: `ISO_VARIANT=minimal|karta|karta-ai` i `build.sh` lägger innehåll i ISO-trädet före xorriso. Kartfilen ska ligga
   som vanlig fil, inte i squashfs. Utdata: `oden-<variant>-<version>.iso` och `.sha256`.
6. **Filer över 4 GiB i ISO 9660**: verifiera att xorriso (multi-extent) och live-boots mount läser dem, annars dela kartan i flera filer
   (t.ex. per landsdel) och låt `pmtiles serve` läsa alla.
7. **Pages**: "Ladda ner" med länk, storlek och SHA256 per variant, plus Etcher-instruktion (`site/`).
8. Dokumentation: ANVANDARGUIDE (bränn med Etcher, första start, nätbehov i minimal), ADMINGUIDE (bygga varianter, ladda upp, uppdatera Pages), STATUS.

## Risker och öppna frågor
- Att p4 går att skapa på en Etcher-bränd sticka är oprovat och avgör upplägget (uppgift 1). Prototypa med minimal-ISO:n först.
- Stickstorlek: ISO + minst ca 8 GB persistens. `karta-ai` kräver troligen 128 GB-stickor; mät.
- Etcher-verifiering av en ISO på tiotals GB tar lång tid; ange förväntad tid i guiden.
- Nedladdningen kräver nät och tillräckligt ledigt utrymme; en avbruten hämtning ska kunna återupptas.
- Secure Boot och p1/p2-layout påverkas inte, men provas på riktig hårdvara.

## Klart när
- Etcher-bränd `minimal`-sticka: startar, skapar krypterad persistens, hämtar karta, visar kartan offline efter omstart.
- Etcher-bränd `karta`- och `karta-ai`-sticka: startar och visar karta (och AI) offline utan nedladdning.
- Strömavbrott under firstboot och under nedladdning lämnar stickan återställningsbar.
- Pages-sidan har fungerande länkar och rätt checksummor för alla tre.
