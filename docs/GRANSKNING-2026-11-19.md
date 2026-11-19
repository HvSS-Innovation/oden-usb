# Ultrareview av feature/stick-bygge (2026-11-19)

Molngranskning av hela branchen mot `main` (45 filer, 1023 tillagda rader, 7 borttagna). Granskningen omfattar
alla steg på branchen, inte bara bygg-ändringarna från samma dag. Alla tio fynd är åtgärdade (markerade nedan). Flera är overifierade mot en riktig stick.
Radnummer i originalrapporten stämmer delvis inte med filerna; mekanismerna är verifierade av granskaren.
Radnumren nedan är de som rapporten uppgav, rättade där den själv rättade dem.

Allvarlighet: **normal** = bugg eller kravbrott, **nit** = mindre problem.

## Data och säkerhet

### 1. Persistence-sökning begränsas inte till USB (normal) — ÅTGÄRDAD
- **Fil:** `build/config/auto/config:13`
- **Problem:** Bootparametrarna har `persistence persistence-encryption=luks` men ingen `persistence-media=`.
  live-boot går igenom alla blockenheter i initramfs och öppnar varje LUKS-partition, interndiskar inkluderade,
  innan etiketten kontrolleras.
- **Följd:** På en dator med krypterad interndisk (t.ex. Debian/Ubuntu med full diskkryptering) frågar boot efter
  den diskens lösenfras. Om den anges öppnas disken och dess filsystem monteras. Det bryter kravet i
  KRAVSPEC/plan 00: "live-systemet monterar aldrig datorns interna diskar". UDISKS_IGNORE-regeln i overlayn gäller
  bara udisks i det körande systemet, inte initramfs.
- **Åtgärd:** Lägg till `persistence-media=removable-usb` i `--bootappend-live`.

### 2. Första start är inte avbrottssäker (normal) — ÅTGÄRDAD (overifierad)
- **Fil:** `build/overlay/usr/local/bin/oden-firstboot:19-53`
- **Problem:** Skriptet anser installationen klar så fort `blkid` visar `crypto_LUKS` (rad 19-23), men LUKS-headern
  är det första som skrivs (rad 51). De riktiga färdigmarkörerna (mkfs, `persistence.conf`, `~/.oden-persist`)
  kommer först på rad 55-64.
- **Följd:** Strömavbrott, utdragen stick eller utloggning mellan `luksFormat` och färdig mkfs (256 MiB journal
  på en ca 55 GB-partition kan ta tiotals sekunder, utan förloppsdialog) ger en stick som aldrig blir användbar.
  Varje boot visar "Data inte upplåst / Starta om och ange lösenfras", ingenting monteras på /home och inget
  sparas. `oden-wipe` hjälper inte, eftersom `luksErase` lämnar `crypto_LUKS`-signaturen. Enda vägen ut är att
  köra `make-stick.sh` igen. Bryter kravet att strömavbrott inte får ge förlorad eller korrupt data.
- **Åtgärd:** Skriv LUKS-headern sist, eller behandla "crypto_LUKS men inget användbart persistence-filsystem eller
  `persistence.conf`" som ofärdigt och erbjud att göra om.
- **Status:** `luksFormat` sätter LUKS2-etiketten `oden-pending`; `oden-firstboot` byter den till `oden` som sista steg.
  Etiketten `oden-pending` (avbruten installation, eller efter `oden-wipe`) ger frågan "Göra om?" vid nästa inloggning
  (`wipefs -a`, sedan ny installation). Läses av `oden-persist-state`, som även `oden-start-gui` använder. Sticks som
  avbröts före ändringen saknar etikett och räknas som låsta. Overifierat: `--label`, `config --label` och
  `luksDump`-raden `Label:` mot riktig cryptsetup, samt strömavbrottstest (steg 03/07). Ingen förloppsdialog under mkfs.

### 3. Lösenfrasens tangentbordslayout skiljer mellan skapande och boot (normal) — ÅTGÄRDAD (overifierad)
- **Fil:** `build/overlay/usr/local/bin/oden-firstboot:33` (zenity) och `:51` (`luksFormat --key-file=-`)
- **Problem:** Lösenfrasen skrivs i X-sessionen med svensk layout, men vid boot skrivs den i initramfs som saknar
  keymap. `keyboard-layouts=se` tillämpas först av live-config efter `switch_root`.
- **Följd:** Å, ä, ö och symboler på olika tangenter ger andra tecken (ö blir `;`, `-` ligger på US `/`).
  Upplåsningen misslyckas och krypterad /home går inte att öppna.
- **Åtgärd:** Lägg svensk keymap i initramfs (t.ex. `KEYMAP=y` plus console-setup), eller begränsa och varna för
  layoutberoende tecken i lösenfrasen.
- **Status:** Lösenfrasen begränsas till a-z, A-Z, 0-9 och blanksteg, minst 16 tecken (`oden-passphrase-ok`, anropas av
  `oden-firstboot`). Det är tecken som ligger på samma tangent på svensk och amerikansk layout, så upplåsningen fungerar
  oavsett vilken keymap initramfs har. Dessutom: `KEYMAP=y` (`initramfs-tools/conf.d`), `/etc/default/keyboard` med
  `XKBLAYOUT=se` och `update-initramfs -u` i bygghooken. Keymap-delen är overifierad (plymouth/`splash` kan hantera
  prompten själv); begränsningen i sig beror inte på den. Lägsta längd 16 är ett val: ändras med `ODEN_MINLEN`.

### 4. Firefox och Obsidian ringer hem (normal) — ÅTGÄRDAD (overifierad)
- **Filer:** `build/overlay/etc/xdg/autostart/oden-browser.desktop:4`, `oden-obsidian.desktop:4`
- **Problem:** Kravet "inga nätanrop utöver Signal, TAK, DHCP, DNS och NTP" (KRAVSPEC, plan/04) uppnås bara för
  NetworkManager (`20-no-connectivity-check.conf`). `firefox-esr` startas på varje inloggning utan policyer och
  Obsidian utan konfiguration.
- **Följd:** Firefox kontaktar `detectportal.firefox.com`, Remote Settings och Safe Browsing. Obsidian gör
  uppdateringskoll mot obsidian.md/GitHub. Paketfångsttestet i steg 07 visar trafik till hosts som
  hotmodellen förbjuder. Ingen `policies.json` finns i repot.
- **Åtgärd:** Leverera `/etc/firefox-esr/policies/policies.json` och Obsidian-inställningar som stänger av alla
  anrop vid start och i bakgrunden.
- **Status:** `policies.json` och `/etc/skel/.config/obsidian/obsidian.json` (`updateDisabled`) finns i overlayn.
  Overifierat: att Firefox läser policyfilen från Debians sökväg (bygghooken kontrollerar/länkar), att nyckeln
  `updateDisabled` stämmer och att Obsidian inte har fler startanrop. Avgörs av paketfångsten i steg 07.

## Byggpipelinen

### 5. Andra bygget som vanlig användare misslyckas (normal) — ÅTGÄRDAD
- **Fil:** `build/build.sh` (`rm -rf out/lb && mkdir -p out/lb`; rapporten angav rad 69-76, rätt ställe är ca rad 25)
- **Problem:** `lb config && lb build` körs som root i en `--privileged`-container utan `--user`, så `out/lb`
  (chroot, binary, cache) blir rootägd. Nästa körning av `build.sh` som vanlig användare får "permission denied"
  på `rm -rf out/lb` och avbryter (`set -e`).
- **Följd:** Varje ombygge (t.ex. efter `bump.sh`) kräver manuell `sudo rm`. Adminguiden säger att man ska köra
  `./build/build.sh` som vanlig användare. Hybrid-steget har redan `--user`, så problemet är känt men inte
  hanterat för lb-steget.
- **Åtgärd:** Rensa `out/lb` inifrån containern eller som root, eller `chown` tillbaka till anroparen efter
  `lb build`.

### 6. `cache/oden-linux` byggs bara om om filen saknas (normal) — ÅTGÄRDAD
- **Fil:** `build/build.sh:16-20`
- **Problem:** Binären kopplas inte till de `oden-source`-, `jre-x64`- och `signal-cli`-rader den byggdes från.
  Verifieringsloopen hoppar över den (`sha=BUILD`) och `fetch.sh` likaså. Bara `bump.sh` på samma maskin tar bort den.
- **Följd:** Admin B kör `git pull` med ny lock, rensar `cache/oden-source` och bygger. `fetch.sh` hämtar nya
  versionen, men gamla `cache/oden-linux` används. Bilden får gammal Oden, gammal JRE och gammal signal-cli,
  medan `/etc/oden-release` och SBOM visar nya låset, utan varning. Kan t.ex. missa en säkerhetsfix.
- **Åtgärd:** Spara indatahashar bredvid binären (t.ex. `cache/oden-linux.inputs` med de tre låsraderna eller
  deras sha256) och bygg om när de skiljer sig.

### 7. `--offline` och "enda nätsteget är fetch.sh" stämmer inte (normal) — ÅTGÄRDAD
- **Fil:** `build/build.sh` (rapporten angav rad 97-122)
- **Problem:** `--offline` hoppar bara över `./fetch.sh`. `docker build` (Dockerfile: `FROM debian:13` och
  `apt-get install`) och `lb build` (debootstrap och apt mot Debians speglar) behöver nätet, och `out/lb` med
  live-builds paketcache raderas varje körning.
- **Följd:** Bygge på frånkopplad maskin med komplett `cache/` misslyckas i debootstrap. Även online är
  Debian-paketen inte pinnade eller verifierade av `artifacts.lock`, så två bygg från samma lock kan skilja sig.
- **Åtgärd:** Antingen ett persistent eller förhämtat paketcache eller snapshot-spegel utanför `out/lb`, eller
  dokumentera att live-build kräver nätet och ta bort offline-löftet (`docs/ADMINGUIDE.md:34`, plan/01).
- **Status:** Offline-löftet gäller stickan, inte bygget. Flaggan heter nu `--no-fetch` (hoppar bara över `fetch.sh`),
  adminguiden och plan/01 säger att bygget kräver nät. Debian-paketen pinnas medvetet inte (releasen är den färdiga ISO:n,
  ett nytt bygge är en ny release; SBOM dokumenterar paketen). Ingen paketcache eller snapshot-spegel behövs.

## Övrigt

### 8. Fel flagga i `pmtiles.service` (normal) — ÅTGÄRDAD
- **Fil:** `build/overlay/etc/systemd/user/pmtiles.service:9` (samma kommandorad i `plan/05`)
- **Problem:** `pmtiles serve ... --bind 127.0.0.1`. go-pmtiles heter flaggan `--interface`. Kong avvisar den
  okända flaggan (TODO-raden ovanför erkänner att syntaxen är overifierad).
- **Följd:** Tjänsten avslutas direkt, startas om tills systemds startgräns nås, och inga kartor serveras på
  `127.0.0.1:8081`. Obsidians offlinekarta är alltid tom.
- **Åtgärd:** `--interface=127.0.0.1` (pinnade go-pmtiles v1.31.2) i både servicefilen och planen.

### 9. `make-stick.sh` tappar `ODEN_ASSETS` (nit) — ÅTGÄRDAD
- **Fil:** `build/scripts/make-stick.sh:11` (läses på rad 16; rapporten angav rad 723-728)
- **Problem:** `exec sudo "$0" "$@"` körs innan `ODEN_ASSETS` läses. sudos `env_reset` släpper variabeln, så
  skriptet tyst faller tillbaka på `build/cache/assets`.
- **Följd:** Antingen "Kartor saknas", eller en stick med fel eller gamla kartor och modeller utan någon varning.
- **Åtgärd:** `exec sudo ODEN_ASSETS="${ODEN_ASSETS:-}" "$0" "$@"`, eller lös sökvägen före omstarten.

### 10. Missvisande notis vid allra första start (nit) — ÅTGÄRDAD
- **Fil:** `build/overlay/usr/local/bin/oden-start-gui:3`
- **Problem:** Utan `~/.oden-persist` visar skriptet "Data inte upplåst / Starta om och ange lösenfras". Både
  `oden-browser.desktop` och `oden-obsidian.desktop` anropar det, så notisen visas två gånger medan
  `oden-firstboot` samtidigt ber användaren skapa en lösenfras.
- **Följd:** En användare som följer notisen startar om innan firstboot är klar.
- **Åtgärd:** Visa notisen bara när p4 faktiskt är LUKS-formaterad (samma `blkid`-kontroll som firstboot), och
  avsluta tyst när p4 är tom.

## Sammanfattning

| # | Fynd | Allvarlighet | Storlek på fixen |
|---|------|--------------|------------------|
| 1 | `persistence-media=removable-usb` saknas (åtgärdad) | normal | en rad |
| 2 | Firstboot inte avbrottssäker | normal | designval (åtgärdad, overifierad) |
| 3 | Keymap saknas i initramfs | normal | designval (åtgärdad, overifierad) |
| 4 | Firefox/Obsidian ringer hem | normal | policyfiler (åtgärdad, väntar på paketfångst i steg 07) |
| 5 | Rootägd `out/lb` stoppar ombygge (åtgärdad) | normal | liten |
| 6 | Gammal `oden-linux` återanvänds (åtgärdad) | normal | liten/medel |
| 7 | `--offline` stämmer inte | normal | designval (åtgärdad) |
| 8 | `--bind` ska vara `--interface` (åtgärdad) | normal | en rad |
| 9 | `ODEN_ASSETS` tappas av sudo (åtgärdad) | nit | en rad |
| 10 | Missvisande notis vid första start (åtgärdad) | nit | liten |
