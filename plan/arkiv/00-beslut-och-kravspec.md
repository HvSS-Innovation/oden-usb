# Steg 00: Beslut och kravspec

**Leverans:** `docs/KRAVSPEC.md` med bekräftade val.

Grundbesluten står i `README.md` (Debian 13 + XFCE, live-boot-persistens, PyInstaller, ingen uppdatering av stickor m.m.).

## Krav
- **Karta:** Protomaps-basemap för Sverige (vektor-PMTiles, OSM 2026-05, ODbL), renderas till raster. Se steg 05.
- **Målmaskiner:** x86_64 UEFI, med eller utan Secure Boot. ARM utanför scope.
- **Minimikrav:** 8 GB RAM för grundsystemet; AI kräver >=16 GB RAM (se steg 06). Stickstorlek >=64 GB.
  Live-systemets egna skrivningar hamnar i RAM; räkna med det i minimikraven.

## Hotmodell
- **Skyddas:** förlorad stick och beslagtagen dator när systemet är avstängt (data i vila, LUKS2).
- **Skyddas inte:** manipulerad dator (evil maid); det dokumenteras.
- **Värddatorn:** live-systemet monterar aldrig datorns interna diskar. USB-minnen monteras som vanligt.
- **Accepterat:** att det syns att stickan är ett ODEN-system, och att Oden-GUI på localhost saknar inloggning.

## Senare (inga krav i nuläget)
- Krav på lösenfrasens styrka.
- Skydd när stickan tas under drift (skärmlås, avstängning vid urdragning).
- Hur nödradering startas (bootmeny, genväg).
- Rutin vid förlorad stick (koppla bort Signal-enhet, spärra TAK-certifikat).

## Acceptanskriterier för hela projektet
- Stick bootar på >=4 olika datormodeller (UEFI, med och utan Secure Boot).
- Första start: lösenfras -> krypterad persistens skapas -> guide för Signal-länkning -> Obsidian öppnar ODEN-valvet.
- Inga nätanrop vid uppstart eller drift utöver Signal, TAK, DHCP, DNS och NTP (verifieras med paketfångst i steg 07).
- Kartan visas utan internet.
- Strömmen bryts mitt i drift -> inga data förloras eller korrumperas.
