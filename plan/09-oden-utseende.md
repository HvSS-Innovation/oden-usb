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

## Gjort (2026-11-20)
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
  Lösenfrasprompten vid upplåsning ritas av temat. Går den att missa trycker man Esc för textläge.

- **Map View och CartoDB (hittat vid första provet, "Tile Unavailable"):** pluginet lägger tillbaka en källa som heter "CartoDB" först i listan om den
  saknas, så index 0 blev CartoDB (externa anrop) trots vår egen källa. `stage.sh` byter därför pluginets standardkälla i `main.js` mot den lokala
  (bygget stoppas om koden inte hittas). Sök, ruttning och Google Places i pluginet ringer bara ut när användaren själv startar dem.
- **Obsidian startläge:** `scripts/make-obsidian-state.sh` skriver `obsidian.json` (valvet `~/ODEN-valv` registrerat, id `6f64656e76616c76`) och
  förfyller Chromiums localStorage med `enable-plugin-<id>=true`. Obsidian slår på community-plugins bara om den nyckeln är `true`
  (kontrollerat i Obsidians kod); annars visas dialogen "Slå på community-plugins" och valvet ser ut som en ren installation.
  Formatet på LevelDB-nyckeln är (`_app://obsidian.md\0\1enable-plugin-<id>`); fungerar det inte syns dialogen som förut.

- **Högupplöst skärm och pekplatta:** `oden-hidpi` (skala 1/2 ur xrandr, `oden.scale=` överstyr) sätter `Gdk/WindowScalingFactor`, Xft/DPI 96 och
  markörstorlek via `/etc/X11/Xsession.d/76oden-hidpi` före skrivbordet; Obsidian får `--force-device-scale-factor`, Firefox `MOZ_USE_XINPUT2=1`.
  Pekplatta (libinput): tvåfingersrullning med naturlig riktning, clickfinger (två fingrar = högerklick), knackning och dra. Kärnparametern
  `fbcon=font:TER16x32` ger större text i textläge; GRUB provar 1440x900 först.

## Klart när
- Startmenyn visar ODEN-logga och svenska texter, och går att läsa på MacBook-skärmen.
- Uppstart, inloggning och skrivbord har samma utseende.
- Testat med och utan Secure Boot (GRUB-tema laddas från ISO:n, inget eget signerat).
