# Steg 03: Krypterad persistens (live-boot + LUKS2)

## Princip
Debian live-boot sköter upplåsning och montering vid varje boot. Vi skriver bara skriptet som skapar
den krypterade partitionen första gången.

- p4: LUKS2 + ext4, filsystemets label `persistence`, med `persistence.conf` som innehåller `/home bind`.
- Kärnparametrar i boot-menyn: `persistence persistence-encryption=luks`.
- p4 formateras **vid första start** (varje stick får egen nyckel), inte vid bygge.

## Innehåll i /home/oden (på p4)
- ODEN-valvet (`~/ODEN-valv`), `~/.oden` (config, DB, bilagor)
- signal-cli-data (`~/.local/share/signal-cli`)
- TAK-certifikat, loggar

## Förstastart (`oden-firstboot`, zenity)
1. Om p4 inte är formaterad: fråga lösenfras och bekräfta. Tillåtna tecken: a-z, A-Z, 0-9 och blanksteg, minst 16 tecken (`oden-passphrase-ok`). Skälet: vid boot skrivs frasen i initramfs utan säker tangentbordslayout, så bara tecken som är samma på svensk och amerikansk layout tillåts. Svensk keymap läggs även i initramfs (`KEYMAP=y`, `/etc/default/keyboard`), men upplåsningen ska inte bero på den.
2. `cryptsetup luksFormat --type luks2 --pbkdf argon2id --pbkdf-memory 524288 --iter-time 2000`
   (fasta värden så att upplåsning fungerar även på svag dator), öppna, `mkfs.ext4 -L persistence`,
   skriv `persistence.conf`, kopiera valvmallen och skapa markörfilen `~/.oden-persist`.
3. Starta om. Därefter frågar live-boot efter lösenfrasen i varje boot och monterar `/home`.
4. Om upplåsningen misslyckas och systemet startar utan persistens: markörfilen saknas, Oden-tjänsterna
   startar inte och en notis säger "Data inte upplåst, starta om". (Verifiera live-boots beteende vid fel lösenfras.)

## Säkerhet
- **Avbrottssäker första start:** `luksFormat --label oden-pending`; etiketten byts till `oden` som sista steg. `oden-pending` (avbruten installation eller efter `oden-wipe`) erbjuder ny installation (`oden-persist-state`, `oden-firstboot`). Overifierat mot riktig cryptsetup.
- **Nödradering:** `oden-wipe` kör `cryptsetup luksErase`. Hur den startas beslutas senare. Ingen header-backup, så raderingen är slutgiltig.
  Dokumentera att flashminne kan behålla gamla block.
- Ingen swap på disk (zram ok), ingen hibernation, core dumps av.
- ext4 med `noatime`; SQLite i WAL-läge om Oden använder SQLite. `sync` vid avstängning.
- Stickan skyddar data i vila, inte mot en manipulerad dator.

## Klart när
- Ny stick: första start ger fungerande krypterad persistens; omstart ber om lösenfras; fel lösenfras ger ingen åtkomst.
- `oden-wipe` gör data oåtkomlig (verifierat med försök att öppna).
- Hård strömavstängning mitt i skrivning ger ingen korrupt DB (testa 10 gånger).

## Status (skript skrivna, ej körtestade)
Skrivna i `build/overlay/usr/local/bin/`: `oden-persist-dev` (hittar p4 på boot-stickan), `oden-firstboot`
(+ autostart i `etc/xdg/autostart/`), `oden-wipe`. Endast `bash -n` körd; cryptsetup-flödet är inte testat.
Bakom skripten:
- p4 måste ha **GPT-partitionsnamn `persistence`** (sätts av `make-stick.sh`, som ännu är TODO). Live-boot
  hittar krypterade partitioner via det namnet, filsystemets label inuti LUKS är `persistence`.
- `oden-firstboot` formaterar bara en partition utan filsystem, och avbryter före formatering om `/opt/oden-template` är tom.
- Lösenfrasen skickas utan radbrytning (`printf '%s'`) så att den är identisk med vad live-boot får vid boot.
- Att verifiera på riktig stick: att live-boot-prompten accepterar frasen, beteendet vid fel fras, `noatime` på p4
  (live-boot monterar själv), 10 hårda strömavbrott.
