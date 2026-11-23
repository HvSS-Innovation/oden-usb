# Steg 10: Bygge utan vår infrastruktur

## Mål
Vem som helst ska kunna bygga ODEN-stickan **utan åtkomst till vår infrastruktur**, med enbart det som finns i git och publika källor på nätet.
Inga magiska länkar: en adress i repot ska peka på en publik uppströmskälla, inte på vår egen lagring.

Det här är ett krav på *bygget*. Att *publicera* ISO-filer på egen lagring är fortfarande vår sak, men hör inte hemma i det som checkas in.

## Principer
1. **Inget av vårt i git.** Inga adresser till vår lagring (Backblaze B2, Cloudflare R2) i spårade filer, lås eller dokumentation. Det som är specifikt för oss kommer in utifrån (miljövariabel, ignorerad fil) vid bygge eller publicering.
2. **Versionslås räcker, bit-identiska bygg krävs inte (beslut 2026-11-22).** Lås på version där det är enkelt (som `artifacts.lock` redan gör). Hashar och digest läggs bara där de är gratis; det gör inget om två bygg inte blir identiska.
3. **Oberoende före reproducerbart.** Det som räknas är att utomstående kan bygga själva från publika källor och få en fungerande, likvärdig ISO (t.ex. med nyare kartdata), inte att resultatet är bit-identiskt.
4. **Bygg och publicering är skilda steg.** Byggskriptet kan aldrig läsa våra nycklar. Publiceringsskriptet gör det, ur miljön.

## Inventering (2026-11-22)
Externa adresser i spårade filer: github.com (55), ollama.com, openstreetmap.org, debian.org, etcher.balena.io med flera publika källor, samt:

| Beroende | Var | Problem | Mål |
|---|---|---|---|
| Rasterkartan `sverige-raster.pmtiles` på Backblaze B2 | `build/maps.lock`, `plan/arkiv/05` | Vår lagring i git. Utomstående kan inte bygga `minimal`; `karta` kräver filen i `cache/assets/maps` utan att säga hur man får den | Kartan byggs ur publika data (uppgift 2) eller anges utifrån (uppgift 3) |
| Vektorkartan `sweden-osm.pmtiles` på B2 | `build/scripts/map/render-map.sh`, `artifacts.lock` (kommentar), `plan/arkiv/05` | Samma | Hämtas ur publik källa, låst på innehåll (uppgift 2) |
| ISO-filer på `publik.hv-sog.se` (R2) | `site/releases.json`, `docs/` | Publiceringsmål, inte byggindata | Kvar, men som parameter, inte hårdkodat i skript och docs (uppgift 4) |
| Debian, Docker-bilder, pip, Ollama-modeller | live-build, taggar, `>=`, `ollama pull` | Inte bit-reproducerbart | Accepteras. Bara versionslås där det är enkelt (uppgift 5, lågprioriterat) |

Redan i ordning: signal-cli, Temurin, Oden (källtarball), ODEN-valv, Obsidian, go-pmtiles och Ollama hämtas från uppströms GitHub-releaser och är låsta med SHA256 i `artifacts.lock`.

## Uppgifter

### 1. Regel och spärr
- Lägg `build/external-hosts.allow` med tillåtna värdnamn (uppströmskällor och publika referenser).
- Lägg ett test i `build/tests/run.sh` som misslyckas om en spårad fil innehåller en adress utanför listan, eller något som liknar en nyckel eller token.
- Kör testet i en GitHub Actions-körning vid varje push (billigt, ingen byggning).

### 2. Kartan ur publika källor
Spike först, innan något byggs om: kontrollera att en publik källa finns och går att hämta.
- Alternativ A: Protomaps publika planetbygge, beskuret till Sverige med `pmtiles extract --bbox` (go-pmtiles finns redan i bygget).
- Alternativ B: Planetiler med Protomaps basemap-profil direkt mot Geofabriks Sverige-extrakt.
- Båda ger vektorkartan som idag ligger på B2. Skriv in vald källa, version, **datum och SHA256** i `render-map.sh`.
- Mät storlek och tid, och bekräfta att resultatet är ODbL-kompatibelt (attribution finns redan).
- Datumet ändras när källan uppdateras: det är en medveten uppgradering (som `bump.sh`), inte något som sker av sig självt.
- Resultat: `render-map.sh` kräver ingenting av oss. Dokumentera i `docs/KARTRENDERING.md`.

### 3. Kartan i bygget utan fast adress
- `build/maps.lock` tas ur git. I stället finns `build/maps.lock.example` (format, inga adresser) och `maps.lock` ignoreras.
- Bygget får kartan på ett av tre sätt, i den ordningen:
  1. Filen ligger redan i `build/cache/assets/maps/` (kontrolleras mot SHA256 om en finns).
  2. `ODEN_MAPS_URL` och `ODEN_MAPS_SHA256` är satta (miljön, inte git).
  3. Annars: `build.sh` skriver ut hur man skapar den med `render-map.sh`, och avbryter.
- `minimal` skriver `ODEN_MAPS_URL` till `assets.lock` i ISO-filen. Därmed känner den som har ISO-filen till adressen. Det är oundvikligt eftersom användarens dator ska hämta filen, och därför ska adressen vara en avsedd publik adress (t.ex. vår R2-domän) och inte en intern bucket.
- Överväg att dela rastret i två filer under 2 GiB så att GitHub Releases kan vara en oberoende spegel (rastret är 2,25 GB). Inte ett krav.

### 4. Publicering skild från bygge
- `build/scripts/publish.sh <variant> <version>`: laddar upp ISO, `.sha256` och SBOM, jämför byte för byte och kör `release-json.sh`.
- Mål och nycklar kommer ur miljön (`ODEN_PUBLISH_ENDPOINT`, `ODEN_PUBLISH_BUCKET`, `ODEN_PUBLISH_BASE_URL`, nycklarna). Inget hårdkodat, ingen `.env` i git (den är redan ignorerad).
- Ta bort `publik.hv-sog.se` ur `docs/` där det är exempel; behåll i `site/releases.json` (det är genererad publiceringsdata).

### 5. Lås det rimliga (lågprioriterat)
Bara det som är enkelt och som annars kan göra bygget omöjligt, inte allt:
- **Debian:** överväg `snapshot.debian.org` med ett datum om bygget börjar fallera när paket försvinner eller ändras. Annars lämnas det som det är (SBOM:en visar vad som ingick).
- **Docker och pip:** versionstaggar räcker. Digest och `--require-hashes` behövs inte; `pip freeze`-filen som redan sparas duger som referens.
- **Ollama-modeller:** notera modellernas namn och version i dokumentationen. Digest-lås behövs inte.

### 6. Verifiera från noll
Acceptanstest, körs på en ren maskin (t.ex. en tillfällig molnserver) utan miljövariabler och utan nycklar:
```
git clone <repo> && cd <repo>
build/scripts/map/render-map.sh          # eller ODEN_MAPS_URL=... från en publik källa
ODEN_VARIANTS=karta ./build/build.sh
```
Godkänt när bygget går igenom, SBOM skrivs, ISO startar och `git grep` efter våra lagringsadresser (B2, R2) ger noll träffar.

## Ordning
1. Uppgift 1 (spärren) och beslut om kartkällan (spike i uppgift 2). Billigt och styr resten.
2. Uppgift 3 och 4 (adresserna ur git, publiceringsskriptet).
3. Uppgift 6 (test från noll) som slutkontroll.
4. Uppgift 5 (lås) bara vid behov.

## Risker och öppna frågor
- Den publika källan kan sluta erbjuda äldre dagsbyggen. Vår egen publicerade kartfil förblir referensen, och datum och SHA256 för källan skrivs ändå in i `render-map.sh` (det är gratis).
- Historiken innehåller redan adresserna (sedan 2026-11-19/20) och ligger i ett publikt repo. Att rensa framåt gör inte historiken ren. Att skriva om historiken kräver force-push och är ett separat beslut; filen på B2 kan i stället flyttas eller göras privat.
- **Beslut 2026-11-22:** att kartadressen finns i ISO-filen (`assets.lock` i `minimal`) är acceptabelt tills vidare och inte kritiskt. Nuvarande `minimal`-bygge och publicering påverkas inte av planen.
- Beslut som återstår: vilken publik kartkälla vi väljer (efter spiken), och vad som ska hända med B2-filen.

## Klart när
- Ingen spårad fil innehåller adresser till vår lagring, och spärren (uppgift 1) håller det så.
- En utomstående kan följa uppgift 6 och få en fungerande ISO med bara det som finns i git och på publika källor.
- Versionerna av det som påverkar resultatet är angivna och SBOM:en visar vad som ingick.
