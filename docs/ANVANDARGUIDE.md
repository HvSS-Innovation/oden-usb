# Användarguide: ODEN-stick

## Det här behöver du
- En USB-sticka (16 GB räcker för Minimal och Med karta, 32 GB eller mer rekommenderas; Med karta och AI kräver större, se nedan) och en dator med UEFI. 8 GB RAM räcker för grundsystemet; AI kräver 16 GB.
- En ISO-fil (se nedan) och ett program som bränner den till stickan, t.ex. balenaEtcher.
- Inget behöver installeras på datorn. Stickan startar sitt eget system och rör inte datorns interna diskar.

## Skaffa och bränn stickan
1. **Välj variant** på nedladdningssidan:
   - **Minimal:** kartorna hämtas från nätet en enda gång vid första start. Kräver internet då.
   - **Med karta:** kartorna ingår. Inget nätbehov alls, men en stor fil (5,2 GiB). Fungerar på en 16 GB-sticka, 32 GB eller mer rekommenderas.
   - **Med karta och AI:** kartor och lokala AI-modeller ingår. Störst fil (13,2 GiB); kräver en större sticka, minst 32 GB, 64 GB rekommenderas.
2. **Kontrollera kontrollsumman** (SHA256) mot det som står på sidan: `sha256sum fil.iso` (Linux/macOS) eller
   `Get-FileHash fil.iso -Algorithm SHA256` (Windows). Stämmer den inte ska filen inte användas.
3. **Bränn** med balenaEtcher: välj ISO-filen, välj stickan, klicka *Flash*. **Allt på stickan raderas.** Det tar en stund för de stora varianterna.
4. Etcher skriver bara ISO-filen; resten av stickan lämnas tom. Den krypterade lagringen skapas på det lediga utrymmet vid första start.
   Du behöver minst 8 GB ledigt utöver ISO-filen (och kartorna i Minimal). Är stickan för liten säger systemet det och sparar ingenting.

## Första start
1. Sätt i stickan, starta datorn och välj USB i startmenyn (ofta F12, F10 eller Esc).
2. Skrivbordet startar. Första gången frågar ODEN efter en **lösenfras** (två gånger). Den krypterar allt du sparar på stickan.
   Lösenfrasen får bara innehålla bokstäverna a-z (inte å, ä, ö), siffror och mellanslag, eftersom tangentbordet vid
   start inte alltid har svensk layout. Det finns ingen minsta längd, men längre är säkrare; fyra ord med mellanslag är ett bra val.
   Väljer du **Nej** på frågan om att skapa den krypterade lagringen skapas ingen lagring: inget sparas och allt är borta
   när datorn stängs av.
   **Glömmer du lösenfrasen går datat inte att få tillbaka.** Det finns ingen återställning.
3. Skapandet av den krypterade lagringen tar en stund. Datorn startar sedan om. **Håll då ner Alt (Mac, ⌥ Option) eller tryck F12
   (PC; ibland F2, F10, F11 eller Esc)** tills startmenyn visas, och välj stickan igen (ofta "EFI Boot"). Den här
   instruktionen visas också i dialogen före omstarten.
4. **Bara Minimal:** efter omstarten och upplåsningen frågar ODEN om kartorna ska hämtas (ca storleken visas).
   Välj *Hämta nu* och låt datorn vara på och ansluten till internet tills det är klart; en förloppsruta visas.
   Avbryts det (nätfel, utdragen sladd) fortsätter hämtningen där den slutade nästa gång du loggar in. Välj du *Senare* frågar den igen vid nästa inloggning.
   Kartorna fungerar först när hämtningen är klar. Därefter behövs inget nät för kartorna.
5. Vid varje start frågar systemet efter lösenfrasen. Skriver du fel och systemet ändå startar visas
   Blir lagringen inte upplåst (fel lösenfras) visas dialogen "ODEN: lagringen är låst" med två val: starta om och skriv lösenfrasen igen, eller radera lagringen och börja om med ny lösenfras (alla sparade data försvinner, och du måste skriva RADERA för att bekräfta). Oden och Obsidian startar inte förrän lagringen är upplåst.

## Koppla Signal
1. Anslut till wifi eller kabel (nätverksikonen uppe till höger).
2. Öppna Oden-gränssnittet (startar automatiskt i webbläsaren, adress `http://127.0.0.1:8080`).
3. Följ länkningen med QR-kod och skanna den i Signal-appen på telefonen. Kräver internet en gång.
4. Signal tar bort länkade enheter som varit inaktiva i ca 30 dagar. Då måste stickan länkas om.

## Daglig användning
- Obsidian öppnar ODEN-valvet automatiskt. Kartan visas utan internet (i Minimal först när kartorna har hämtats).
- **Skärm:** på högupplösta skärmar (t.ex. MacBook retina) görs allt dubbelt så stort automatiskt vid inloggning. Passar det inte kan du
  välja skala i startmenyn: tryck `e` på "Starta ODEN" och lägg till `oden.scale=1` (eller `oden.scale=2`) på raden som börjar med `linux`.
- **Pekplatta:** rulla med två fingrar (naturlig riktning, som på Mac), knacka = klick, tryck med två fingrar = högerklick, tre = mittenklick,
  dra med knackning. Vill du ha vanlig rullriktning: `NaturalScrolling` i `/etc/X11/xorg.conf.d/40-libinput-touchpad.conf` (kräver nytt bygge).
- TAK-servrar och certifikat lägger du in själv i Odens gränssnitt. Inget är förinställt.
- Utan nätverk fungerar analys som vanligt; mottagning av Signal-meddelanden pausar tills nät finns.
- AI (Ollama) startar bara på datorer med minst 16 GB RAM, och bara om stickan byggts med AI.

## Avsluta
Stäng av datorn via menyn och dra ur stickan först när datorn är avstängd.

## Byta till en ny stick
Stickor uppdateras inte. Ny version = ny stick. Kopiera först ut det du vill behålla (valv, `~/.oden`) till ett
annat USB-minne, och länka Signal på nytt på den nya stickan.

## Nödradering
`oden-wipe` i en terminal förstör nyckeln till den krypterade lagringen och stänger av datorn. Det går inte att ångra.
Flashminne kan behålla gamla block, så detta skyddar mot åtkomst med lösenfras, inte mot en laboratorieundersökning.

## Vad stickan skyddar
- **Skyddas:** förlorad stick, eller beslagtagen dator när stickan är avstängd (data i vila).
- **Skyddas inte:** en manipulerad dator (t.ex. en keylogger i datorns firmware) eller en stick som tas medan den är igång.
