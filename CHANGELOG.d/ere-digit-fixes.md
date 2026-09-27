---
bump: patch
section: Fixed
---

- `pre-commit-no-new-features`: la detección de specs con distinto número SE nunca funcionaba (`\d` dentro de `grep -E`); ahora bloquea de verdad en ramas con PR abierto. Mismo fallo corregido en el contador de `daily-activation-plan.sh`. Los tests con repos fixture usan identidad git local.
