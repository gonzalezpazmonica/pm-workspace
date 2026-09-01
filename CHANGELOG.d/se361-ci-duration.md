---
version_bump: patch
section: Added
---

### Added

- SE-361 Presupuesto de tiempo de CI: `ci-duration-agg.py` mide duración por job con p50/p95 y detecta jobs sobre presupuesto (5 min default); `ci-duration.sh` genera el informe (offline con cache local). Alimenta la etapa `ci` de SE-360. 5 pytest + 4 bats tests.
