---
version_bump: patch
section: Fixed
---

### Fixed

- savia-runs: los subcomandos que escriben el ledger toman un cerrojo exclusivo (20 actualizaciones simultáneas de runs distintos perdían 15); un PR mergeado va a DONE aunque el run no haya hecho finish (salía en READY TO MERGE); status --json con ledger vacío devuelve JSON.

