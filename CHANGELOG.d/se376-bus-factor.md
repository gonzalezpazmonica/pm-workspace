---
version_bump: patch
section: Fixed
---

### Fixed

- bus-factor-analysis calibrada (SE-376): el scan respeta .mailmap, ya no descarta humanos con email ci@ o noreply de GitHub, lee rutas no ASCII y subdirectorios, marca UNKNOWN (no CRITICAL) los modulos sin historial y deja de avisar con DeprecationWarning; report y distribute ya no usan el scan de otro proyecto y fallan con exit 2 ante JSON invalido; scan.sh propaga el fallo del motor. 25 tests nuevos (certificado 88).

