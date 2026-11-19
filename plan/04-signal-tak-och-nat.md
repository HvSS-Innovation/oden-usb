# Steg 04: Nätverk, Signal-länkning och TAK

## Princip
Nätverk används bara av Signal (via signal-cli) och TAK, plus DHCP, DNS och NTP. Inga paketuppdateringar och ingen telemetri.
Det uppnås genom att inget annat är konfigurerat att ringa hem, inte genom vitlistor.

## Uppgifter
1. **Nätverkshantering:** NetworkManager + XFCE-applet för wifi/Ethernet. Wifi-firmware (`firmware-iwlwifi`,
   `firmware-realtek`, `firmware-atheros`, `firmware-brcm80211` m.fl.) ingår i bilden. Anslutningskontrollen avstängd.
2. **Brandvägg (nftables):** blockera inkommande (utom loopback och etablerade anslutningar). Utgående öppet.
3. **Signal-länkning:** Odens befintliga länkflöde (QR-kod i Web GUI) när nät finns. Länkning kräver internet *en gång*.
   Dokumentera att Signal tar bort länkade enheter som varit inaktiva ca 30 dagar; då måste stickan länkas om.
4. **Frånkopplat läge:** Oden/ODEN ska fungera utan nät (mottagning pausar, analys fungerar). Tydlig statusindikator.
5. **TAK:** `pytak` ingår i Oden-bundlen. Import av `.p12`/PEM till `~/.oden` via Web GUI eller filkopiering.
6. **Tid:** NTP (systemd-timesyncd) på. Rätt klocka krävs för TLS; dokumentera det i felsökningen.

## Klart när
- Med wifi: Signal-länkning och mottagning av ett testmeddelande fungerar -> Markdown i valvet.
- Utan nät: systemet startar, analys fungerar, inga felloopar eller hängningar.
- Inkommande anslutningar från en annan dator blockeras.
