# SPEC-183 — Reconciliation 3-bucket en drift-auditor

**Date:** 2026-06-24

## Implementado

- `scripts/reconciliation-resolver.py`: 3-bucket classifier (auto-resolve / evolution / conflict-doc)
  - Input: JSON drift file from drift-auditor
  - Decision tree: Step 1 EVOLUTION (timeline/CHANGELOG), Step 2 AUTO-RESOLVE (newer + more authoritative OR minor counter drift), Step 3 CONFLICT-DOC (ambiguous, requires human)
  - `--apply` flag: auto-resolve rewrites files with History block; conflict-doc creates `output/conflicts/{topic}-{YYYYMMDD}.md` with `status: open` frontmatter
  - Metrics logged to `.savia/reconciliation-stats.jsonl`
- `tests/scripts/test_reconciliation_resolver.py`: 11 pytest covering all 3 buckets, apply mode, CLI, metrics

Agente `reconciler` y piloto scripts ya existían del trabajo previo; este PR agrega el script Python + tests.

## Tests: 11 passed
