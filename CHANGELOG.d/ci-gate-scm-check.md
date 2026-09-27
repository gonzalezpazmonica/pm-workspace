---
bump: patch
section: Fixed
---

- `ci-extended-checks.sh` check #7 (SCM Freshness) regeneraba `.scm/` en el repo y, si fallaba, ejecutaba `git checkout -- .scm/`, descartando cambios sin commitear. Ahora usa `generate-capability-map.py --check` (solo lectura, comparación byte a byte; antes solo comparaba la cabecera). Su suite pasa de 3,5 min a 33 s y ya no muta `.scm`. `ci-reliability-gate.sh` rechaza argumentos desconocidos (antes los ignoraba) y su test de `--fix-empty-dirs` trabaja sobre un workspace temporal.
