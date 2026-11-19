# Adminguide: bygga och skriva ODEN-stickor

> Status: bygg- och skrivskripten är syntaxkontrollerade och delvis testade (partitionering på gles fil, uppackning med
> fejkade artefakter). Ett helt bygge och en skriven stick är inte körda än.

## Krav på byggmaskinen
Linux med docker, `gdisk` (sgdisk), `fdisk` (sfdisk), `e2fsprogs`, `parted`, `curl`, `tar`. Nät behövs bara för `fetch.sh`.

## Artefakter
Allt externt står i `build/artifacts.lock` (namn, URL, SHA256). Poster med `PENDING` måste låsas först:
`build/fetch.sh --pin <namn>` hämtar och skriver ut checksumman som förs in i filen. `build.sh` vägrar bygga med
`PENDING` eller avvikande checksumma.

Formatet avgörs av filens första byte (tar/gzip/xz/zstd, zip eller ELF). Förväntad layout efter uppackning:
`oden-linux` ger `/opt/oden/oden`, `go-pmtiles` ger `/opt/pmtiles/pmtiles`, `ollama` ger `/opt/ollama/bin/ollama`,
Obsidian är en AppImage (`/opt/obsidian/obsidian`) och `oden-valv` är valvmallen. Stämmer inte layouten avbryts bygget.

## Bygga bilden
```
./build/build.sh            # hämtar, verifierar, bygger i container -> build/out/oden.img + SBOM.txt
./build/build.sh --offline  # hoppar över nedladdning (cache/ måste vara komplett)
```

## Skriva en stick
Lägg assets under `build/cache/assets/` (eller sätt `ODEN_ASSETS`):
`maps/` (kartfil, krävs) och `ollama/` (modeller, bara för `--with-ai`).
```
sudo ./build/scripts/make-stick.sh [--with-ai] build/out/oden.img /dev/sdX
```
Skriptet kräver en flyttbar hel disk på minst 60 GB och frågar innan allt raderas. Layout: p1 EFI, p2 live,
p3 `oden-assets` (ext4, skrivskyddad på `/srv/oden-assets`), p4 `persistence` (krypteras vid första start).

## Byta karta eller modeller
Det kräver en ny stick (assets skrivs bara av `make-stick.sh`).

## Nycklar
Varje stick får egen LUKS-nyckel vid första start; det finns ingen central nyckel och ingen header-backup.
Förlorad lösenfras = förlorad data. Vid förlorad stick: koppla bort stickans enhet i Signal och spärra dess TAK-certifikat.

## Version
`/etc/oden-release` i bilden innehåller bygg-datum och checksumma för `artifacts.lock`.
