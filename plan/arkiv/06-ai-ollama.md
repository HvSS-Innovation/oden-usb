# Steg 06: AI / Ollama (valfritt)

## Princip
Ollama och modeller finns på stickan men startas bara på maskiner med tillräckligt RAM. Ollama använder NVIDIA-GPU
om drivrutinen är laddad, annars CPU.
ODEN fungerar utan AI (detektion är aldrig AI-beroende), så ett avstängt Ollama är ett fullgott läge.

## Modeller (enligt ODEN-analys)
- `qwen3-vl:4b`  (bild)
- `qwen3:8b`     (text, chatt, djupanalys)
Totalt ca 8 GB. Hämtas med `ollama pull` vid bygget (inget versionslås) och läggs på p3:
`OLLAMA_MODELS=/srv/oden-assets/ollama`. Med `make-stick.sh --with-ai`; utan flaggan blir p3 mindre.

## Uppgifter
1. Ollama-binär i `/opt/ollama/`. Verifiera att Ollama kan läsa modeller från skrivskyddad katalog
   (`OLLAMA_NOPRUNE=1`); annars monteras p3 skrivbar.
2. **NVIDIA (enkla vägen):** Debians `nvidia-driver` ingår, osignerad. Ingen egen nyckel och ingen MOK-registrering.
   - Secure Boot av: modulen laddas, Ollama använder GPU:n.
   - Secure Boot på: modulen laddas inte, skärmen går på enkel grafikdrivare (simpledrm/modesetting), Ollama kör på CPU.
   - Verifiera att den enkla grafiken fungerar i XFCE när modulen inte laddas (nouveau är svartlistad av `nvidia-driver`).
   - Kontrollera att drivrutinsversionen i Debian 13 stöder de grafikkort som används.
3. **Resurskontroll** (`ExecCondition` i `ollama.service`): RAM >= 16 GB, annars startar inte Ollama
   och en notis visas: "AI avstängd (för lite minne)".
4. `ollama.service` lyssnar på `127.0.0.1:11434`, `OLLAMA_MAX_LOADED_MODELS=1`.
5. Kontrollera att ODEN-pluginet hittar Ollama på standardporten och att modellnamnen matchar.
6. Dokumentera förväntad svarstid per maskinklass (CPU och NVIDIA).

## Klart när
- På maskin med >=16 GB RAM: bildanalys och textanalys i ODEN fungerar helt offline.
- På maskin med NVIDIA och Secure Boot av: Ollama använder GPU:n (`ollama ps` visar GPU).
- På maskin med NVIDIA och Secure Boot på: systemet startar med fungerande skärm och AI på CPU.
- På svag maskin: inget Ollama startas, inga fel i ODEN, tydlig statusrad.
