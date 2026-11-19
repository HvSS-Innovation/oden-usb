# Användarguide: ODEN-stick

> Status: skriven mot det som är byggt, men stickan är inte körd på riktig hårdvara än. Punkter märkta (?) är overifierade.

## Det här behöver du
- ODEN-stick (USB, minst 64 GB) och en dator med UEFI. 8 GB RAM räcker för grundsystemet; AI kräver 16 GB.
- Inget behöver installeras. Stickan startar sitt eget system och rör inte datorns interna diskar.

## Första start
1. Sätt i stickan, starta datorn och välj USB i startmenyn (ofta F12, F10 eller Esc).
2. Skrivbordet startar. Första gången frågar ODEN efter en **lösenfras** (två gånger). Den krypterar allt du sparar på stickan.
   Lösenfrasen ska vara minst 16 tecken och får bara innehålla bokstäverna a-z (inte å, ä, ö), siffror och mellanslag,
   eftersom tangentbordet vid start inte alltid har svensk layout. Fyra ord med mellanslag är ett bra val.
   **Glömmer du lösenfrasen går datat inte att få tillbaka.** Det finns ingen återställning.
3. Skapandet av den krypterade lagringen tar en stund. Datorn startar sedan om.
4. Vid varje start frågar systemet efter lösenfrasen. Skriver du fel och systemet ändå startar visas
   "Data inte upplåst": starta om och försök igen. Oden och Obsidian startar inte förrän lagringen är upplåst.

## Koppla Signal
1. Anslut till wifi eller kabel (nätverksikonen uppe till höger).
2. Öppna Oden-gränssnittet (startar automatiskt i webbläsaren, adress `http://127.0.0.1:8080`).
3. Följ länkningen med QR-kod och skanna den i Signal-appen på telefonen. Kräver internet en gång.
4. Signal tar bort länkade enheter som varit inaktiva i ca 30 dagar. Då måste stickan länkas om.

## Daglig användning
- Obsidian öppnar ODEN-valvet automatiskt. Kartan visas utan internet.
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
