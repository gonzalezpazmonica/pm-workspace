---
version_bump: patch
section: Fixed
---
- `push-pr.sh` terminaba en silencio sin crear el PR cuando la rama no tenía commits `feat:`/`fix:`: con `set -euo pipefail`, el `grep` sin coincidencias que deduce el título abortaba el script. Ahora cae al primer commit no-chore y, si no hay, al nombre de la rama. `pr-plan.sh` detecta el éxito por una URL `/pull/N` y no por cualquier línea con `github.com` (el `git push` imprime `To https://github.com/...` y hacía pasar por buena una ejecución sin PR). Afectó a #1165 y #1166, creados a mano.
