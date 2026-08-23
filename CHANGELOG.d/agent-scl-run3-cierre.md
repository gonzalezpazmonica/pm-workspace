---
version_bump: minor
section: Added
---

### Added

- `docs/learning-proposals/LP-20260823-l11-run3.md`: LP sanitizada del cierre de la línea L11 SAGI (run-3) — la memoria cross-sesión y la coherencia de criterio las produce el algoritmo que inyecta el sustrato antes del LLM, no el modelo aislado. Sin métricas ni paths (CRIT-001).
- `docs/rules/domain/scl-001-learning-loop.md`: política "Sustrato antes que LLM" — toda decisión de criterio/memoria inyecta recall del sustrato antes de consultar al modelo. Confirmada con señal real en P2/P3 del run-3.