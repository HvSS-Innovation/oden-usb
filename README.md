# ODEN-stick

Ett komplett ODEN-system som startar från en USB-sticka och går att köra helt utan nätverk. Stickan innehåller Debian 13 (XFCE), Oden, Obsidian med ODEN-valvet, lokal karta (Sverige, zoom 0–14) och krypterad persistens (LUKS2). AI (Ollama) är valfritt.

Webbplats: https://hvss-innovation.github.io/oden-usb/

## Varianter

Tre ISO-filer som bränns med balenaEtcher:

- **minimal:** kartorna hämtas en gång vid första start
- **karta:** kartorna ingår
- **karta-ai:** kartor och lokala AI-modeller ingår

## Bygga

```
./build/tests/run.sh                                   # offline-tester av skripten
ODEN_VARIANTS=minimal,karta,karta-ai ./build/build.sh  # -> build/out/*.iso + SBOM.txt
```

Kräver Linux med Docker och nät. Se [`docs/ADMINGUIDE.md`](docs/ADMINGUIDE.md).

## Innehåll

| Mapp | Innehåll |
|---|---|
| `build/` | Bygg-pipeline: live-build-konfig, overlay, låsta artefakter, skript och tester |
| `plan/` | Plan per steg (00–09) |
| `docs/` | Kravspec, status, användarguide, adminguide, felsökning, kartrendering, granskning |
| `site/` | Webbplatsen (statisk HTML), publiceras med GitHub Pages från `main` |
| `maps/` | Kartkälla (vektor), används för att rendera rastret |

## Dokumentation

- [Användarguide](docs/ANVANDARGUIDE.md)
- [Adminguide](docs/ADMINGUIDE.md)
- [Felsökning](docs/FELSOKNING.md)
- [Kravspec och hotmodell](docs/KRAVSPEC.md)
