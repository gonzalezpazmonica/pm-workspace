---
version_bump: patch
section: Fixed
---

### Fixed

- Auto-label PRs cross-repo (fork): el job `label` fallaba con `SyntaxError` en PRs desde forks y el token del workflow no siempre podia escribir labels en PRs cuyo head vive en otro repo. Ahora el script ignora el error de 403 cross-repo (labels son cosmeticos) y el flujo ya no aborta. Tambien corrige la llave de cierre del bloque `if` que rompia el parseo del script.
