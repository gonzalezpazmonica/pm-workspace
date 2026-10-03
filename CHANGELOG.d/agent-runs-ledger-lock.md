---
version_bump: patch
section: Fixed
---

### Fixed

- savia-runs: los subcomandos que escriben el ledger toman un cerrojo exclusivo (20 actualizaciones simultáneas de runs distintos perdían 15); un PR mergeado va a DONE aunque el run no haya hecho finish (salía en READY TO MERGE); status --json sin ledger o vacío devuelve todas las columnas vacías; el hook capture-cost sigue sin tocar nada sin SAVIA_RUN_ID y espera el cerrojo como mucho 5 s; el cerrojo de macOS (mkdir) rompe cerrojos huérfanos; la regla de columnas tiene una sola definición.

