---
bump: patch
section: Fixed
---

- `operator-grant.sh`: sin operadora identificable ya no emite un permiso con `grantor` vacío (fail-closed) y resuelve el perfil activo desde la raíz del repo, no desde el cwd.
- `block-pat-file-write`: `pat` se detecta como token delimitado en cualquier posición del nombre (`my-pat-file.txt`), sin falsos positivos por subcadena.
