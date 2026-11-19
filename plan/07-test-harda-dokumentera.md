# Steg 07: Test, härdning och dokumentation

## Maskinvarutest (matris)
4–6 datorer: olika tillverkare, Intel/AMD, med och utan Secure Boot, med och utan NVIDIA
(minst en bärbar med hybridgrafik), 8 GB och >=16 GB RAM.
För varje: boot, wifi, grafik, upplåsning, Oden, Obsidian + karta, Ollama (om >=16 GB), GPU-användning (NVIDIA med Secure Boot av).
Resultat i `docs/HW-MATRIS.md`.

## Funktionstest (E2E)
- Följ ODEN-analys `docs/E2E_BIN1.md` mot stickan: Signal-meddelande -> 7S-rapport -> Obsidian -> analys.
- Strömavbrottstest, USB-urdragning, full disk.

## Säkerhet och härdning
- Paketfångst (tcpdump) under 30 min tomgång: inga anrop utöver Signal, TAK, DHCP, DNS, NTP.
- Ta bort onödiga tjänster/paket (avahi, cups, bluetooth om ej behövs).
- Granska att inga hemligheter hamnar i bilden (bygg-token, cache). Kontrollera SBOM.
- Test av `oden-wipe`.
- Datorns interna diskar monteras inte och syns inte i filhanteraren.

## Dokumentation (svenska)
- `docs/ANVANDARGUIDE.md`: skriv stickan, första start, länka Signal, daglig användning, avstängning,
  kopiera ut data innan man byter till en ny stick.
- `docs/ADMINGUIDE.md`: bygga ny stick, byta karta/modeller (= nytt bygge), nyckelhantering.
- `docs/FELSOKNING.md`: bootproblem (Secure Boot, BIOS-inställningar), NVIDIA (stäng av Secure Boot för GPU-AI), wifi, fel klocka, glömd lösenfras (= data förlorad).
- Versionspolicy: stickversion = datum + Oden-version + ODEN-analys-version (visas i boot-meny och i Obsidian).

## Klart när
- Alla acceptanskriterier i steg 00 uppfyllda och dokumenterade.
- En person som inte byggt systemet kan skriva en stick och komma igång enbart med användarguiden.
