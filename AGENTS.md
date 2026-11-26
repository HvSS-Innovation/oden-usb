## Git & deploy workflow
- Integration: commit och push direkt till `main` (ingen PR); användaren ber om det uttryckligen ("commita och pusha").
- Commits: på svenska, kort rubrik med vad som ändrats; Claude-attribution enligt miljön.
- Före commit: kör `bash build/tests/run.sh` (ska ge 0 FEL).
- Webbplatsen (`site/**`): GitHub Actions (`.github/workflows/pages.yml`) publicerar via GitHub Pages vid push som ändrar `site/**`. Inget manuellt steg.
- ISO-publicering (manuell, kräver uttryckligt OK från användaren eftersom R2-uppladdning är publik och radering inte går att ångra):
  1. Bygg: `ODEN_VARIANTS=minimal,karta ./build/build.sh` (`karta-ai` byggs med samma xorriso-steg ur `build/out/oden.iso` plus `assets/maps` och `assets/ollama`).
  2. Ladda upp ISO, `.sha256` och `SBOM.txt` till R2 under `oden/<commit>/` (nycklar i `.env`, skriv aldrig ut dem); kontrollera SHA256 mot `https://publik.hv-sog.se/oden/<commit>/`.
  3. `build/scripts/release-json.sh https://publik.hv-sog.se/oden/<commit> > site/releases.json`, uppdatera `docs/STATUS.md`, `docs/KALLOR.md` och `site/status.html`, committa och pusha.
  4. Radera äldre omgångar i R2 först efter att den nya är verifierad. Rör aldrig `oden/maps/` (minimal hämtar kartan därifrån).
- Provbyggen delas som länk under `oden/test-<commit>/` och raderas efter test.
