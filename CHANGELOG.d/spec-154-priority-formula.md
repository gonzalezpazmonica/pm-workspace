---
date: 2026-06-24
spec: SPEC-154
slices: 1, 2, 3, 6
status: implemented
---

# SPEC-154 — Fórmula canónica V×U/E (Slices 1-3 + 6)

## Ficheros creados

### Slice 1 — Función pura + schema
- `scripts/priority/__init__.py`
- `scripts/priority/score.py` — función pura `score(PriorityInput) → PriorityOutput`, `normalize_effort()`, dataclasses
- `docs/schemas/priority-v1.json` — JSON Schema v1 para PriorityInput/Output

### Slice 2 — Extensión frontmatter + backfill
- `scripts/priority/backfill-specs.py` — backfill + validate + dry-run
- `scripts/priority/backfill_specs_module.py` — módulo importable para tests
- `scripts/priority/validate-spec-frontmatter.sh` — validador CI, exit 1 si inconsistente

### Slice 3 — Adapters
- `scripts/priority/adapters/__init__.py`
- `scripts/priority/adapters/rice_to_vue.py` — RICE → PriorityInput
- `scripts/priority/adapters/wsjf_to_vue.py` — WSJF → PriorityInput
- `scripts/priority/adapters/adhoc_to_vue.py` — text priority/effort → PriorityInput (confidence < 1.0)

### Slice 6 — Reglas + tests + reporte
- `docs/rules/domain/priority-canonical-formula.md` — escala value/urgency/effort, árbol decisión, anti-patterns
- `docs/rules/domain/priority-persistence.md` — contrato 4 campos, política backfill, fuente de verdad
- `scripts/priority/roadmap-priority-report.sh` — tabla markdown ordenada por priority_score
- `tests/scripts/test_priority_formula.py` — 24 tests pytest (todos passing)
- `tests/bats/test-priority-formula.bats` — 11 tests BATS (todos passing)
- `output/priority-decisions/.gitkeep`

## Tests

```
pytest tests/scripts/test_priority_formula.py -q
→ 24 passed

bats tests/bats/test-priority-formula.bats
→ 11/11 ok
```

## Backfill dry-run (stats reales)

```
Total files scanned: 281
  verified-consistent:    1   (tiene los 4 campos y son consistentes)
  backfilled-from-priority: 2  (tienen priority+effort, se puede calcular score)
  marked-needs-triage:   62   (sin metadata de priorización — AC-07: no se inventan valores)
  skipped:              216   (status IMPLEMENTED/REJECTED/etc — no activos)
```

## ACs cubiertos

| AC | Estado |
|---|---|
| AC-01 idempotencia | ✓ test_idempotency_100_calls |
| AC-02 4 campos o needs-triage | ✓ backfill + validate |
| AC-03 priority_score ±5% | ✓ validate-spec-frontmatter.sh |
| AC-04 RICE adapter (Spearman base) | ✓ rice_to_vue.py |
| AC-06 counterfactual top-3 | ✓ test_counterfactual_* |
| AC-07 no inventar campos | ✓ marked-needs-triage logic |
| AC-11 backfill idempotente | ✓ test_backfill_idempotent |
| AC-12 regla canónica ≤150L | ✓ priority-canonical-formula.md |
