---
version_bump: minor
section: Added
---

### Added

- **SE-274 S2 — Golden sets de tribunales**: 3 datasets JSONL hand-labeled
  (`tests/evals/{code-review-court,truth-tribunal,recommendation-tribunal}/cases.jsonl`,
  50 casos cada uno) con `should_trigger[]`, `should_not_trigger[] {case, route_to}`
  y `capabilities[]`. Cierran los modos de fallo de cada tribunal (FP/FN/severity
  en Code Review; factual/hallucination/incoherence/completeness/calibration en
  Truth; sycophancy/concession/framing/authority-claim en Recommendation).
- **SE-316 — Eval-lint de golden sets**: `scripts/eval-lint.sh` valida que cada
  caso cumple el schema (`config/eval-case.schema.json`), los contadores mínimos
  por tribunal (>=5 should_trigger, >=4 should_not_trigger, >=1 capability) y que
  cada `route_to` (salvo `none`/`external:`) resuelve contra `docs/RESOLVER.md` y
  `SKILLS.md`. Gate **G16** en `pr-plan-gates.sh` (solo corre si el PR toca
  `tests/evals/` o el schema) + job CI **Eval Lint** bloqueante.
- **Tests**: `tests/test-eval-lint.bats` (20 casos: AC-S1, AC-S2, cobertura,
  aislamiento).

### Changed

- `docs/propuestas/SE-274-agent-quality-framework.md`: AC-S2.1..S2.3 completados.
- `docs/propuestas/SE-316-eval-lint-golden-sets.md`: status PROPOSED → IMPLEMENTED.
- `.gitignore`: `savia-vaults.quotas.json` (runtime state del MCP, regenerable).
