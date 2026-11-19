# Felsökning

> Status: byggd från planen; ännu inte provad mot verkliga fel.

| Symptom | Troligt skäl | Åtgärd |
|---|---|---|
| Stickan syns inte i startmenyn | Fel startläge i BIOS | Aktivera UEFI-boot från USB; prova annan USB-port |
| Startar inte med Secure Boot på | Misslyckad signaturkedja | Stickan använder Debians signerade shim/grub; prova Secure Boot av för att utesluta |
| Skärmen går på enkel grafik, AI långsam | NVIDIA-drivrutinen är osignerad och laddas inte med Secure Boot på | Stäng av Secure Boot för GPU-AI, annars körs AI på CPU |
| "Data inte upplåst" | Fel lösenfras vid boot | Starta om och ange rätt lösenfras |
| Lösenfras glömd | | Data kan inte återfås. Skapa ny stick |
| Första-start-dialogen visar "Oväntat innehåll på p4" | p4 har ett filsystem | Stickan är felskriven eller manipulerad; skriv om den med `make-stick.sh` |
| TLS-fel i Signal/TAK | Fel klocka | Anslut till nät och vänta på NTP (systemd-timesyncd); kontrollera datum |
| Wifi saknas | Wifi-kort utan firmware i bilden | Använd kabel; notera modellen i `HW-MATRIS.md` |
| Kartan visas inte | Kartfilen saknas på p3 eller p3 inte monterad | Kontrollera `ls /srv/oden-assets/maps`; skriv om stickan med `make-stick.sh` |
| AI startar inte | Under 16 GB RAM, eller stickan byggd utan `--with-ai` | Förväntat beteende |
