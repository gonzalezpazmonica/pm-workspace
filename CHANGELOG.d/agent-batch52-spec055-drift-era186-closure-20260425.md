## [6.3.0] — 2026-04-25

Batch 52 — SPEC-055 status drift correction + Era 186 hook ratchet **CLOSURE** + sweep bug fix + baseline tighten.

### Changed
- `docs/propuestas/SPEC-055-test-auditor.md`: status PROPOSED → IMPLEMENTED. Resolution section con verificación de los 4 scripts deliverables + auditor self-test (15 tests, score 83). Acceptance criteria final: 5/5 cumplidos.
- `docs/ROADMAP.md`: Era 186 extension marcada CLOSED 2026-04-25. Tabla milestones extendida con batches 49-51 (51/58 → 58/58). Header bumped v6.2.0 → v6.3.0 con SPEC-055 IMPLEMENTED y baseline tighten anotado.
- `.ci-baseline/hook-critical-violations.count`: 5 → 4 (current measurement = 4 críticos consistentes en últimos 5 hook-bench runs). Ratchet never-loosen mantenido.

### Fixed
- `scripts/test-auditor-sweep.sh`: bug aislado donde sweep extraía campo `.score` del auditor JSON pero el auditor emite `total`. Resultado: sweep siempre reportaba 0% compliance vs 100% real. Impact LOW (script no usado en CI, solo en su propio test). Fix de 1 línea: `.score` → `.total`. Verificación post-fix: 329/329 BATS files compliant ≥80 = **100% baseline**.

### Context
PR-A del plan post-#695: cleanup ligero antes de atacar SPEC-121/122/124 que requieren más trabajo.

**Era 186 hook coverage ratchet — métricas finales:**
- Duración: 2026-04-21 → 2026-04-25 (5 días)
- Batches: 39-51 (13 iteraciones)
- Hooks tested: 18/58 (31%) → 58/58 (100%) — **+40 hooks, +69 puntos**
- Tests añadidos: 1100+ certified con score ≥80
- Avg score: ~90 (después de internalizar feedback_test_auditor_score_targets)
- Bugs reales descubiertos: 4 (cwd-changed-hook, emotional-regulation-monitor, memory-auto-capture, SE-071 block-branch-switch-dirty)
- Drift hooks: 0 (CI-enforced via `.ci-baseline/hook-untested-count.count`)

**Próximas iteraciones (Era 187):**
- PR-B: SPEC-121 handoff convention completion (3 ACs faltantes)
- PR-C: SPEC-122 LocalAI emergency hardening completion (4 ACs faltantes)
- Backlog: SPEC-124 pr-agent wrapper (5 ACs ~3-4h)

Version bump 6.2.0 → 6.3.0.
