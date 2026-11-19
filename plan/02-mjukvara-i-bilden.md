# Steg 02: Mjukvara i bilden

## Installationsplatser (skrivskyddad p2)
```
/opt/oden/                 # Oden PyInstaller-bundle (inkl. signal-cli/ och jre-x64/)
/opt/obsidian/             # Obsidian AppImage (extraherad, FUSE behövs ej)
/opt/pmtiles/pmtiles       # go-pmtiles
/opt/ollama/               # Ollama-binär (steg 06)
/opt/oden-template/        # ODEN-valv (mall, kopieras till /home vid första start)
```
Assets (p3) monteras skrivskyddat på `/srv/oden-assets` (karta, modeller).

## Föranalys
- Bekräfta att Oden går att bygga med `s7_watcher.spec` på Linux och att `bundle_utils` hittar signal-cli/JRE i bundlen.
- Se till att `pytak[with-crypto]` (TAK) följer med i bundlen.

## Uppgifter
1. Lägg Oden-bundlen i `/opt/oden`; verifiera `signal-cli --version` utan nät.
2. Packa upp Obsidian; kör med `--no-sandbox` endast om nödvändigt.
3. Lägg ODEN-valvmallen (`ODEN-valv-<v>.zip`, operativt). Ev. övningsvariant med `ODEN-ovning`.
4. **Skrivbord:** XFCE, svensk locale och tangentbordslayout, autologin för användaren `oden`, skärmlås vid inaktivitet.
5. **systemd-user-tjänster:** `oden.service` (webbgränssnitt på localhost), `pmtiles.service` (steg 05),
   `ollama.service` (steg 06, villkorad). Startar bara om `/home` ligger på krypterad persistens
   (kontrollera markörfil `~/.oden-persist`, se steg 03).
6. **Autostart:** Obsidian öppnar valvet, Oden-GUI i webbläsare.
7. **Förkonfigurera** `config.ini` (valvsökväg, `oden_home` i `/home/oden`) och Obsidian (pluginen betrodda).
8. **Avaktivera** Obsidian auto-update, apt-timers och NetworkManagers anslutningskontroll. NTP får vara på.
9. **Ingen hibernation:** maska `hibernate.target` och `hybrid-sleep.target`. Ingen swap på disk (zram ok).

## Klart när
- Med upplåst persistens startar Oden och Obsidian utan nätverksanslutning och valvet visar kartan (steg 05).
- `ss -tulpn` visar bara lokala lyssnare.
