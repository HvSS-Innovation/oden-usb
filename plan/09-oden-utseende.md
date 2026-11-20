# Steg 09: ODEN-utseende (startmeny och bakgrund)

## Bakgrund
Startskärmen (GRUB) visar live-builds standardtema: "Debian GNU/Linux 13 (trixie) amd64", byggtid, versioner av
live-build/live-boot/live-config och menyn "Live system (amd64)". Den ska i stället se ut som ODEN. Samma gäller
bakgrunden under uppstart och inloggning.

## Beslut (2026-11-20)
- Loggan är `oden_1024.png` ur Odens källkod (`images/`). Kopieras in i repot (`build/config/config/bootloaders/` och
  overlayn), så att bygget inte beror på cachen.
- Bakgrund och övrig styling tas i samma steg som startmenyn.
- Görs efter att inloggningsfelet (se `docs/FELSOKNING.md`) är löst, så att det inte blandas in i felsökningen.

## Uppgifter
1. **GRUB-tema:** eget tema i `build/config/config/bootloaders/` (`theme.txt`, bakgrundsbild, teckensnitt). live-build
   använder det i stället för standardtemat. Mörk bakgrund, ODEN-logga, ODEN-färger.
2. **Texter:** rubrik "ODEN" och versionen från `git describe`. Meny: "Starta ODEN", "Starta ODEN (säkert läge)".
   Ta bort byggtid och versionsrader för live-*-paketen. "Utilities…" tas bort om den inte behövs.
   Hjälptexten längst ned på svenska.
3. **Läsbarhet på MacBook (retina):** GRUB visar låg upplösning. Sätt större teckensnitt (`grub-mkfont`) och
   `gfxmode`; prova på riktig hårdvara.
4. **Bakgrund under uppstart:** plymouth-tema med loggan (kärnparametern `splash` används redan).
5. **Inloggning och skrivbord:** lightdm-bakgrund och XFCE-skrivbordsbakgrund med ODEN-styling.

## Gjort (2026-11-20, overifierat på hårdvara)
- Logga och färger: `build/branding/oden-logo.png` (korp på olivgrönt tyg). Bakgrund `#606959` (tygets färg), text mörkblå
  `#1f2733`. `build/scripts/make-branding.py` skapar splash, bakgrund och ikon (Pillow, körs i Docker); resultatet är incheckat.
- GRUB: `build/config/config/bootloaders/grub-pc/` (splash.png, theme.cfg, config.cfg, grub.cfg, live-theme/theme.txt och
  DejaVu-teckensnitt i 22/30 pt via grub-mkfont). Menyn: "Starta ODEN", "Starta ODEN (säkert läge)" (nomodeset noapic nosmp),
  "Verktyg...". Svensk hjälprad. gfxmode höjd från 800x600. live-builds egen text (Built, versioner) finns i dess splash och är borta.
- Bakgrund: `usr/share/oden/background.png` sätts på alla skärmar av `oden-set-background` (autostart); lightdm-gtk-greeter använder samma.
- Genvägar: skrivbordet (`/etc/skel/Desktop`: Oden, Obsidian, Terminal) och programmenyn (`/usr/share/applications`). Ikon: `oden.png`.
- **Plymouth (uppstartsbild):** efter första provet visade skärmen en svart ruta mellan GRUB och skrivbordet. Temat `oden` är spinner-temat
  (två-stegs-modulen, snurra och lösenfrasdialog för upplåsning vid boot) med loggan som vattenstämpel och bakgrund `#606959`.
  `oden.plymouth` och `watermark.png` ligger i overlayn; bygghooken kopierar resten från spinner och kör `plymouth-set-default-theme oden`.
  Risk: lösenfrasprompten vid upplåsning ritas av temat; provas på hårdvara. Går den att missa trycker man Esc för textläge.

## Klart när
- Startmenyn visar ODEN-logga och svenska texter, och går att läsa på MacBook-skärmen.
- Uppstart, inloggning och skrivbord har samma utseende.
- Testat med och utan Secure Boot (GRUB-tema laddas från ISO:n, inget eget signerat).
