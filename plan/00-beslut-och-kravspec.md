# Steg 00: Beslut och kravspec

**Leverans:** `docs/KRAVSPEC.md` med bekräftade val.

Grundbesluten står i `README.md` (Debian 13 + XFCE, live-boot-persistens, PyInstaller, ingen uppdatering av stickor m.m.).

## Krav
- **Målmaskiner:** x86_64 UEFI, med eller utan Secure Boot. ARM utanför scope.
- **Minimikrav:** 8 GB RAM för grundsystemet; AI kräver >=16 GB RAM (se steg 06). Stickstorlek >=64 GB.
  Live-systemets egna skrivningar hamnar i RAM; räkna med det i minimikraven.

## Kvar att besluta
1. **Kartkälla.** Mottagen: OpenMapTiles-vektor (MBTiles, z0–14, Sverige, OSM 2020). Kvar: licensvillkor från MapTiler,
   och om 2020 års data duger (annars `planetiler` från Geofabrik). Se steg 05.
2. **Hotmodell (kort).** Förlorad stick och beslagtagen dator. Skadlig/manipulerad dator (evil maid) skyddas inte,
   det dokumenteras. Bestämmer lösenfrasregler.

## Acceptanskriterier för hela projektet
- Stick bootar på >=4 olika datormodeller (UEFI, med och utan Secure Boot).
- Första start: lösenfras -> krypterad persistens skapas -> guide för Signal-länkning -> Obsidian öppnar ODEN-valvet.
- Inga nätanrop vid uppstart eller drift utöver Signal, TAK, DHCP, DNS och NTP (verifieras med paketfångst i steg 07).
- Kartan visas utan internet.
- Strömmen bryts mitt i drift -> inga data förloras eller korrumperas.
