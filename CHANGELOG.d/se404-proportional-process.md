---
version_bump: minor
section: Changed
---
- SE-404 G13 v2: busca specs también en `docs/specs/`, reconoce seis formatos de criterio de aceptación (`- AC1:`, `- **AC1**`, `- [ ] AC-1`…) y rutas con comodín en la spec; registra cada `Scope-trace: skip` en `output/g13-overrides.jsonl`. Nueva vía `Fix-trace: <test>`: un PR que arregla un test pasa G13 sin override si el test falla en la base, pasa en HEAD y todo lo cambiado está en su cadena (verificado en un worktree temporal). Code Review Court: una corrección por revisión (`COURT_MAX_FIX_ROUNDS = 1`); `court-review.sh validate` rechaza `.review.crc` con más rondas.
