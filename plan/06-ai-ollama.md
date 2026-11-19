# Steg 06: AI / Ollama (valfritt)

## Princip
Ollama och modeller finns på stickan men startas bara på maskiner med tillräckligt RAM. Endast CPU, inga GPU-drivrutiner.
ODEN fungerar utan AI (detektion är aldrig AI-beroende), så ett avstängt Ollama är ett fullgott läge.

## Modeller (enligt ODEN-analys)
- `qwen3-vl:4b`  (bild)
- `qwen3:8b`     (text, chatt, djupanalys)
Totalt ca 8 GB. Hämtas med `ollama pull` vid bygget (inget versionslås) och läggs på p3:
`OLLAMA_MODELS=/srv/oden-assets/ollama`. Med `make-stick.sh --with-ai`; utan flaggan blir p3 mindre.

## Uppgifter
1. Ollama-binär i `/opt/ollama/`. Verifiera att Ollama kan läsa modeller från skrivskyddad katalog
   (`OLLAMA_NOPRUNE=1`); annars monteras p3 skrivbar.
2. **Resurskontroll** (`ExecCondition` i `ollama.service`): RAM >= 16 GB, annars startar inte Ollama
   och en notis visas: "AI avstängd (för lite minne)".
3. `ollama.service` lyssnar på `127.0.0.1:11434`, `OLLAMA_MAX_LOADED_MODELS=1`.
4. Kontrollera att ODEN-pluginet hittar Ollama på standardporten och att modellnamnen matchar.
5. Dokumentera förväntad svarstid per maskinklass.

## Klart när
- På maskin med >=16 GB RAM: bildanalys och textanalys i ODEN fungerar helt offline.
- På svag maskin: inget Ollama startas, inga fel i ODEN, tydlig statusrad.
