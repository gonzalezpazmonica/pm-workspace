---
bump: patch
section: Fixed
---

- Higiene de CI: el patrón `**/*-secret*` de `.gitignore` ocultaba el código y los docs del propio escáner de secretos (SE-239, SE-353); ahora se exceptúan uno a uno sin abrir el patrón, con test que lo garantiza. `output/pr-plan-20260628.md` deja de estar versionado. 23 scripts recuperan el bit de ejecución y la suite de SE-238 pierde espacios finales y gana 5 tests. `ci-reliability-gate.sh` pasa 7/8. G6b de `pr-plan` informa la puntuación real en vez de 0.
