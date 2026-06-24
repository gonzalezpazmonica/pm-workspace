# SPEC-152 — Hierarchical Orchestrator Delegation (MVP)

**Date:** 2026-06-24

## Implementado (MVP ligero)

- `scripts/hierarchical-orchestrator.py`: feature-lead assignment for task plans
  - Input: JSON task tree (list or `{tasks: [...]}`)
  - Assigns feature-lead to subtask groups with > N children (default: 3)
  - Domain detection via keyword scoring: backend / frontend / infra / qa
  - Rationale per assignment explaining threshold + domain detection
  - Summary statistics: delegated/direct counts, lead distribution
- `tests/scripts/test_hierarchical_orchestrator.py`: 10 pytest covering domain detection, thresholds, CLI

Full refactor of dev-orchestrator + court-orchestrator (Slices 2-6) deferred to Q3 2026 per spec bucket.

## Tests: 10 passed
