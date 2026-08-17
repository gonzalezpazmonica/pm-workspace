---
version_bump: minor
section: Added
---

### Added

- **SCL-001 Savia Continuous Learning — bucle cerrado (implementado)**: captura
  canónica (`learning-proposal.sh`), ciclo de vida shadow→canary→active→superseded
  con gate anti-auto-activación y rollback auditable (`learning-lifecycle.sh`,
  `learning-rollback.sh`), métrica `L` determinista + reporte de ventana
  (`learning-metric.sh`, `learning-report.sh`) y guard de agnosticismo a LLM
  (`learning-guard.sh`). 27 tests BATS + E2E de bucle cerrado. Regla
  `docs/rules/domain/scl-001-learning-loop.md`. SCL-001 APPROVED → IMPLEMENTED.
