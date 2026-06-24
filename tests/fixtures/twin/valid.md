---
twin_id: "test-project"
spec_version: "1.0"
last_refresh: "2026-06-23T07:35:14Z"
stale_after_days: 14
token_budget: 2000
health: green
predictions:
  sprint_slip:
    value: 0.1
    confidence: 0.9
    evidence_ref: "tests/fixtures/twin/evidence.md"
  next_blocker:
    value: "none detected"
    confidence: 0.8
    evidence_ref: "tests/fixtures/twin/evidence.md"
  scope_drift:
    value: 0.05
    confidence: 0.7
    evidence_ref: "tests/fixtures/twin/evidence.md"
  aggregate_health:
    value: green
    confidence: 0.85
    evidence_ref: "tests/fixtures/twin/evidence.md"
---

## Estado

Sprint activo: Sprint 1. Items: 5 abiertos, 0 bloqueantes.

## Reglas

Regla 1: WIP limit 3.

## Predicciones

Sin slip esperado. Sin bloqueantes. Scope estable. Salud verde.
