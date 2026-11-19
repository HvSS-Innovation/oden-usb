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
1. Om p4 inte är formaterad: fråga lösenfras och bekräfta (inga styrkekrav i nuläget).
2. `cryptsetup luksFormat --type luks2 --pbkdf argon2id --pbkdf-memory 524288 --iter-time 2000`
   (fasta värden så att upplåsning fungerar även på svag dator), öppna, `mkfs.ext4 -L persistence`,
   skriv `persistence.conf`, kopiera valvmallen och skapa markörfilen `~/.oden-persist`.
3. Starta om. Därefter frågar live-boot efter lösenfrasen i varje boot och monterar `/home`.
4. Om upplåsningen misslyckas och systemet startar utan persistens: markörfilen saknas, Oden-tjänsterna
   startar inte och en notis säger "Data inte upplåst, starta om". (Verifiera live-boots beteende vid fel lösenfras.)

## Säkerhet
- **Nödradering:** `oden-wipe` kör `cryptsetup luksErase`. Hur den startas beslutas senare. Ingen header-backup, så raderingen är slutgiltig.
  Dokumentera att flashminne kan behålla gamla block.
- Ingen swap på disk (zram ok), ingen hibernation, core dumps av.
- ext4 med `noatime`; SQLite i WAL-läge om Oden använder SQLite. `sync` vid avstängning.
- Stickan skyddar data i vila, inte mot en manipulerad dator.

## Klart när
- Ny stick: första start ger fungerande krypterad persistens; omstart ber om lösenfras; fel lösenfras ger ingen åtkomst.
- `oden-wipe` gör data oåtkomlig (verifierat med försök att öppna).
- Hård strömavstängning mitt i skrivning ger ingen korrupt DB (testa 10 gånger).
