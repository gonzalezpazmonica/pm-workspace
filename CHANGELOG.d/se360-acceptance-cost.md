---
version_bump: patch
section: Added
---

### Added

- SE-360 Costo por cambio aceptado: `acceptance-cost-agg.py` descompone el tiempo de aceptación de un PR por etapa (cola_ci/ci/revision/remediacion/gobernanza) desde los ledgers locales (SE-349/SE-355), con p50/p95 y bottleneck; `acceptance-cost.sh` genera el informe. 6 pytest + 3 bats tests.
