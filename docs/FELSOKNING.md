# Felsökning

**Verktyget `oden-admin`:** dubbelklicka på ikonen *ODEN Admin* på skrivbordet, eller skriv `oden-admin` i en terminal. Menyn har nätverk (wifi, test, nätverkskort och drivrutiner), tjänster (status, start, stopp, omstart, logg), versioner, maskinvara och omstart av datorn. `oden-admin rapport` sparar allt i en textfil i hemkatalogen som du kan skicka vidare.


| Symptom | Troligt skäl | Åtgärd |
|---|---|---|
| Stickan syns inte i startmenyn | Fel startläge i BIOS | Aktivera UEFI-boot från USB; prova annan USB-port |
| Startar inte med Secure Boot på | Misslyckad signaturkedja | Stickan använder Debians signerade shim/grub; prova Secure Boot av för att utesluta |
| Skärmen går på enkel grafik, AI långsam | NVIDIA-drivrutinen är osignerad och laddas inte med Secure Boot på | Stäng av Secure Boot för GPU-AI, annars körs AI på CPU |
| "ODEN: lagringen är låst" (eller notisen "Data inte upplåst") | Fel lösenfras vid boot | Välj "Starta om och skriv lösenfrasen igen". Är den glömd: "Radera lagringen och börja om" (kräver att du skriver RADERA, alla data går förlorade) |
| Lösenfras glömd | | Data kan inte återfås. Skapa ny stick |
| Första-start-dialogen visar "Oväntat innehåll på lagringspartitionen" | Persistens-partitionen har ett filsystem | Stickan är felskriven eller manipulerad; skriv om den med `make-stick.sh` |
| TLS-fel i Signal/TAK | Fel klocka | Anslut till nät och vänta på NTP (systemd-timesyncd); kontrollera datum |
| Wifi vill inte ansluta | Fel landskod, rfkill eller drivrutin | Dubbelklicka *ODEN Wifi* (eller `oden-wifi`): den låser upp radion, listar nät och ansluter. Utan skärm/tangentbord: lägg `oden-wifi.txt` (en rad `nätverk;lösenord`, eller `nätverk;lösenord;dolt` för dolt nät) på ett USB-minne och kör `oden-wifi fil` |
| Wifi saknas | Wifi-kort utan firmware i bilden | Använd kabel; notera modellen i `HW-MATRIS.md` |
| Kartan visas inte | Kartfilen saknas på p3 eller p3 inte monterad | Kontrollera `ls /srv/oden-assets/maps` och `findmnt /srv/oden-assets`. Minimal: kartorna är inte hämtade än (logga in igen). Annars skriv om stickan med `make-stick.sh` eller använd en ISO med karta |
| AI startar inte | Under 16 GB RAM, eller stickan byggd utan `--with-ai` | Förväntat beteende |
| Notisen "Ingen persistens … för lite ledigt utrymme" | Stickan har för lite plats kvar efter ISO-filen (kräver 8 GiB, plus utrymme för kartor i Minimal) | Använd en större stick |
| Notisen "Ingen persistens … hittar inte boot-mediet" eller "ingen läsbar GPT" | Systemet startades från skiva/annan källa, eller bildens partitionstabell skadades | Bränn om stickan med Etcher och starta från USB |
| Notisen "Hittade inte partitionen för lagring" efter att den skapats | Kärnan såg inte den nya partitionen (`partx`) | Starta om; finns den inte då: `sudo partx -a /dev/sdX` (stickan) och kontrollera `lsblk -o NAME,PARTLABEL`. Rapportera i HW-MATRIS |
| Fråga "En tidigare installation av den krypterade lagringen blev aldrig klar" | Strömavbrott, utdragen stick eller `oden-wipe` | Svara *Gör om*; inget data har sparats på den |
| Lösenfrasen avvisas | Innehåller å/ä/ö eller symboler | Använd a-z, 0-9 och mellanslag (t.ex. fyra ord) |
| "Kartor kan inte hämtas: hittade ingen assets-partition" | Minimal-stickan fick ingen assets-partition (skapas vid första start) | Bränn om och gör första starten om; kontrollera `lsblk -o NAME,PARTLABEL` (ska visa `oden-assets` och `persistence`) |
| "Hämtningen misslyckades" (nätfel) | Internet bröts under hämtningen av kartor | Anslut och logga in igen; hämtningen fortsätter där den slutade |
| "Kontrollsumman … stämmer inte" / "fel storlek" | Skadad eller manipulerad nedladdning (filen raderas) | Försök igen; upprepas det är källan fel: meddela den som byggt stickan |
| Kartan visas inte på Med karta-stickan | `maps/` på mediet bind-monterades inte | `systemctl status oden-assets.service`, `findmnt /srv/oden-assets/maps`, `ls /run/live/medium/maps` |

## Kartan visar "Tile Unavailable" eller hämtar från cartocdn
Map View lägger själv tillbaka en källa som heter "CartoDB" om den saknas. Bygget byter pluginets standardkälla i `main.js` mot den lokala kartan
(`scripts/stage.sh`). Kontrollera med Ctrl+Shift+I → Network i Obsidian att rutorna hämtas från `127.0.0.1:8081/sverige/…`. Rutor över kartans
sista zoomnivå (`MAP_MAXZOOM` i `build/map.conf`) ger 404.

## Tecknen hamnar fel på ett Mac-tangentbord (§ och < omkastade, @ eller | saknas)
På Apple-datorer sätts svensk Mac-layout (`se`, variant `mac`) av `oden-keyboard`. Är `§` och `<` ändå omkastade är det kärnans `hid_apple`:
prova kärnparametern `hid_apple.iso_layout=0` (eller `1`) på `linux`-raden i startmenyn (tryck `e`). Lösenfrasen (a–z, siffror, mellanslag) påverkas inte.

## Allt är för litet eller för stort på skärmen
`oden-hidpi` väljer skala 1 eller 2 vid varje inloggning ur skärmens pixeltäthet (minst 144 dpi och 2000 pixlar bred ger 2). Överstyr
genom att trycka `e` i startmenyn och lägga till `oden.scale=1` eller `oden.scale=2` på `linux`-raden. Kontrollera värdet med `oden-hidpi scale`
och vad skärmen rapporterar med `xrandr --current`.

## Inloggningsruta i stället för autologin; `oden`/`live` fungerar inte
Orsak (verifierad med felsökningsbild 2026-11-20): paketet `user-setup` saknades. live-config hoppar då över steget
`0030-user-setup`, så användaren `oden` skapas aldrig (`getent passwd oden` tomt, `sudo: unknown user oden` i
live-config-loggen, "could not identify user (from getpwnam(oden))" i journalen). Paketet är bara rekommenderat och
bygget använder `--apt-recommends false`. Åtgärd: `user-setup` i paketlistan, och bygghooken avbryter om det saknas.
Felsökning: bygg med `ODEN_DEBUG=1`; rapporten visas på tty1 efter ca 60 s (Ctrl+Alt+F1).
