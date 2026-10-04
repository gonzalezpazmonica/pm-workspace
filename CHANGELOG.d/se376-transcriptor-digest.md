---
version_bump: patch
section: Fixed
---

### Fixed

- transcriptor-digest: scan ya no ofrece reuniones sin transcribir y mark-digested rechaza marcarlas (exit 3), escribe meta.json de forma atómica, verifica tras escribir y no declara éxito si falla (comillas en la ruta, meta.json corrupto, sin python3); `--force` exige `--confirm <carpeta>` y se niega ante actividad reciente, y el exit 3 ya no sugiere forzar.

