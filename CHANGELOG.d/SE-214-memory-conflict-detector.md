# SE-214 — Memory Conflict Detection

**Date:** 2026-06-24

## Implementado

- `scripts/memory-conflict-detector.py`: semantic conflict detection for MEMORY.md entries
  - Input: `--memory-file MEMORY.md` or `--store .memory-store.jsonl`
  - Detects 3 conflict types via keyword overlap (no LLM required):
    - `direct_contradiction`: negation flip on same topic
    - `value_disagreement`: same topic, different numeric values
    - `temporal_overlap`: overlapping date references with conflicting state
  - Output JSON: `{conflicts: [{entry_a, entry_b, conflict_type, description, similarity}], total, source}`
  - Emits WARN only — does not modify entries (Rule #5)
  - `--output FILE` for JSONL logging
- `tests/scripts/test_memory_conflict_detector.py`: 7 pytest

Note: `scripts/memory-conflict-check.sh` already handles write-time WARN (SE-214 AC1-AC5). This Python script adds typed conflict classification and bulk scan over existing memory.

## Tests: 7 passed
