# Kravspec: ODEN-stick

Bekräftade beslut. Detaljer per steg finns i `plan/`.

## Bas
- Debian 13 live (`live-build`), XFCE, x86_64 UEFI, med eller utan Secure Boot (Debians signerade shim/grub). ARM utanför scope.
- Krypterad persistens: live-boots LUKS2, bara `/home` sparas.
- Oden som PyInstaller-binär (inkl. signal-cli och JRE), Obsidian med ODEN-valv, go-pmtiles, valfri Ollama.
- Allt hämtas vid bygget. Inget installeras över nät hos användaren. Ingen uppdatering av stickor: ny version = ny stick.

## Krav
- **Karta:** Protomaps-basemap för Sverige (vektor-PMTiles, OSM 2026-05, ODbL), renderas en gång till raster. Se steg 05.
- **Minimikrav:** 8 GB RAM för grundsystemet; AI kräver >=16 GB RAM. Stickstorlek >=64 GB.
  Live-systemets egna skrivningar hamnar i RAM.
- Ingen hibernation, ingen swap på disk (zram ok).
- Ingen brandväggsvitlista: inkommande blockeras, utgående öppet.
- NVIDIA-drivrutinen ingår osignerad: med Secure Boot på laddas den inte (enkel grafik, AI på CPU).

## Hotmodell
- **Skyddas:** förlorad stick och beslagtagen dator när systemet är avstängt (data i vila, LUKS2).
- **Skyddas inte:** manipulerad dator (evil maid). Dokumenteras.
- **Värddatorn:** live-systemet monterar aldrig datorns interna diskar. USB-minnen monteras som vanligt.
- **Accepterat:** att det syns att stickan är ett ODEN-system, och att Oden-GUI på localhost saknar inloggning.

## Senare (inga krav i nuläget)
- Krav på lösenfrasens styrka.
- Skydd när stickan tas under drift (skärmlås, avstängning vid urdragning).
- Hur nödradering startas (bootmeny, genväg).
- Rutin vid förlorad stick (koppla bort Signal-enhet, spärra TAK-certifikat).

## Acceptanskriterier
- Stick bootar på >=4 olika datormodeller (UEFI, med och utan Secure Boot).
- Första start: lösenfras -> krypterad persistens -> guide för Signal-länkning -> Obsidian öppnar ODEN-valvet.
- Inga nätanrop vid uppstart eller drift utöver Signal, TAK, DHCP, DNS och NTP (paketfångst, steg 07).
- Kartan visas utan internet.
- Strömavbrott mitt i drift ger ingen förlorad eller korrumperad data.
