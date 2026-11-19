# Felsökning

> Status: byggd från planen; ännu inte provad mot verkliga fel. Raderna för Etcher-flödet (längst ned) är skrivna mot koden och oprovade.

| Symptom | Troligt skäl | Åtgärd |
|---|---|---|
| Stickan syns inte i startmenyn | Fel startläge i BIOS | Aktivera UEFI-boot från USB; prova annan USB-port |
| Startar inte med Secure Boot på | Misslyckad signaturkedja | Stickan använder Debians signerade shim/grub; prova Secure Boot av för att utesluta |
| Skärmen går på enkel grafik, AI långsam | NVIDIA-drivrutinen är osignerad och laddas inte med Secure Boot på | Stäng av Secure Boot för GPU-AI, annars körs AI på CPU |
| "Data inte upplåst" | Fel lösenfras vid boot | Starta om och ange rätt lösenfras |
| Lösenfras glömd | | Data kan inte återfås. Skapa ny stick |
| Första-start-dialogen visar "Oväntat innehåll på lagringspartitionen" | Persistens-partitionen har ett filsystem | Stickan är felskriven eller manipulerad; skriv om den med `make-stick.sh` |
| TLS-fel i Signal/TAK | Fel klocka | Anslut till nät och vänta på NTP (systemd-timesyncd); kontrollera datum |
| Wifi saknas | Wifi-kort utan firmware i bilden | Använd kabel; notera modellen i `HW-MATRIS.md` |
| Kartan visas inte | Kartfilen saknas på p3 eller p3 inte monterad | Kontrollera `ls /srv/oden-assets/maps` och `findmnt /srv/oden-assets`. Minimal: kartorna är inte hämtade än (logga in igen). Annars skriv om stickan med `make-stick.sh` eller använd en ISO med karta |
| AI startar inte | Under 16 GB RAM, eller stickan byggd utan `--with-ai` | Förväntat beteende |
| Notisen "Ingen persistens … för lite ledigt utrymme" | Stickan har för lite plats kvar efter ISO-filen (kräver 8 GiB, plus utrymme för kartor i Minimal) | Använd en större stick |
| Notisen "Ingen persistens … hittar inte boot-mediet" eller "ingen läsbar GPT" | Systemet startades från skiva/annan källa, eller bildens partitionstabell skadades | Bränn om stickan med Etcher och starta från USB |
| Notisen "Hittade inte partitionen för lagring" efter att den skapats | Kärnan såg inte den nya partitionen (`partx`) | Starta om; finns den inte då: `sudo partx -a /dev/sdX` (stickan) och kontrollera `lsblk -o NAME,PARTLABEL`. Rapportera i HW-MATRIS |
| Fråga "En tidigare installation av den krypterade lagringen blev aldrig klar" | Strömavbrott, utdragen stick eller `oden-wipe` | Svara *Gör om*; inget data har sparats på den |
| Lösenfrasen avvisas | Innehåller å/ä/ö/symboler eller är kortare än 16 tecken | Använd a-z, 0-9 och mellanslag, minst 16 tecken (t.ex. fyra ord) |
| "Kartor kan inte hämtas: hittade ingen assets-partition" | Minimal-stickan fick ingen assets-partition (skapas vid första start) | Bränn om och gör första starten om; kontrollera `lsblk -o NAME,PARTLABEL` (ska visa `oden-assets` och `persistence`) |
| "Hämtningen misslyckades" (nätfel) | Internet bröts under hämtningen av kartor | Anslut och logga in igen; hämtningen fortsätter där den slutade |
| "Kontrollsumman … stämmer inte" / "fel storlek" | Skadad eller manipulerad nedladdning (filen raderas) | Försök igen; upprepas det är källan fel: meddela den som byggt stickan |
| Kartan visas inte på Med karta-stickan | `maps/` på mediet bind-monterades inte | `systemctl status oden-assets.service`, `findmnt /srv/oden-assets/maps`, `ls /run/live/medium/maps` |
