# ODEN-stick: bootbar offline-distribution

Mål: en USB-stick som man startar datorn från och som direkt ger ett fungerande ODEN-system
(Oden Signal/TAK-intag + Obsidian med ODEN-analysvalv + lokala kartor + valfri lokal AI).

## Grundprincip: enkelhet
Välj alltid den enklaste lösningen som uppfyller kraven. Använd det Debian redan har i stället för egen kod.
Hellre en funktion mindre än en rörlig del till.

## Utgångspunkter (beslutade)
- **Inget installeras över nätet hos användaren.** Allt hämtas vid *bygget* och bakas in.
  Nät används bara för Signal/TAK-trafik och Signal-länkning (QR) vid första start.
- **Bas:** Debian 13 live via `live-build`, skrivbordsmiljö **XFCE**.
- **Persistens:** Debian live-boots inbyggda krypterade persistens (LUKS2). Bara `/home` sparas.
- **Oden körs som PyInstaller-binär** (bundlar signal-cli + JRE, samma layout som `s7_watcher.spec`).
- **Kartor:** raster-PMTiles serveras lokalt med `go-pmtiles serve`. Källan är vektor (OpenMapTiles) och renderas till raster en gång (steg 05).
- **AI/Ollama:** startas bara på datorer med tillräckligt RAM. Använder NVIDIA-GPU om den finns och drivrutinen laddas, annars CPU.
- **Secure Boot:** stöds via Debians signerade shim/grub, inget eget arbete.
- **NVIDIA-drivrutin** ingår men signeras inte. Med Secure Boot på laddas den inte och systemet kör enkel grafik + CPU-AI.
- **Ingen uppdatering av stickor.** Ny version = ny stick. Användaren kopierar ut relevant data först.
- **Ingen hibernation**, ingen swap på disk.
- **Ingen brandväggsvitlista.** Inkommande blockeras, utgående är öppet.
- **Obsidian** får distribueras i bilden (licens bekräftad).
- **TAK-servrar** konfigureras av användaren i Odens GUI; inget förkonfigureras i bilden.

## Källrepon
- https://github.com/NicklasAndersson/oden  (Bin 1: Signal -> Markdown)
- https://github.com/larsnor/ODEN-analys    (Bin 2: Obsidian-plugin + valv)
- 7s-rapport: endast referens, ingår inte.

## Steg
| Fil | Steg |
|---|---|
| `00-beslut-och-kravspec.md` | Beslut och kravspec |
| `01-bygg-pipeline.md` | Bygg-pipeline och artefaktlås |
| `02-mjukvara-i-bilden.md` | Oden, signal-cli, Obsidian, valv, skrivbord |
| `03-krypterad-persistens.md` | Krypterad persistens med live-boot, förstastart |
| `04-signal-tak-och-nat.md` | Nätverk, Signal-länkning, TAK |
| `05-kartor-pmtiles.md` | go-pmtiles + Map View |
| `06-ai-ollama.md` | Ollama, modeller, resurskontroll |
| `07-test-harda-dokumentera.md` | Test, härdning, dokumentation |

MVP: steg 00–03, minimal 04 (nätverk + Signal-länkning, utan TAK) och 05.

## Målbild: stickans layout (minst 64 GB)
```
p1  EFI           ~512 MB
p2  Live-system   ~6–8 GB          squashfs: Debian, XFCE, Oden (+signal-cli, JRE), Obsidian, go-pmtiles, Ollama-binär
p3  Assets        efter innehåll   ext4, okrypterad, monteras skrivskyddad: PMTiles, Ollama-modeller (valfritt)
p4  Persistence   resten           LUKS2 + ext4, label "persistence": /home (valv, ~/.oden, signal-cli-data, TAK-cert, loggar)
```
p3 innehåller inget känsligt (kartor och modeller) och skrivs av `make-stick.sh`.
p4 krypteras vid första start så att varje stick får egen nyckel.
