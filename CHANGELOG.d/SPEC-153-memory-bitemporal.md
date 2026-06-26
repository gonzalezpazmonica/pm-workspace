# SPEC-153 — Memory Bi-temporal (MVP)

**Date:** 2026-06-24

## Implementado (MVP ligero)

- `scripts/memory-bitemporal.py`: bi-temporal memory extension
  - `--add --entry TEXT --occurred DATE --learned DATE`: register fact with two timestamps
  - `--query --at DATE`: returns memory state as of that date (learned <= at AND not yet invalidated)
  - `--list`: all entries with timestamps
  - `--invalidate --id ID --at DATE`: mark entry as superseded
  - Storage: `~/.savia/memory-bitemporal.db` (SQLite, standalone, WAL mode)
  - Compatible with MEMORY.md via `sync_to_memory_md()` utility
  - Date validation, UUID entry IDs
- `tests/scripts/test_memory_bitemporal.py`: 7 pytest covering add, query-at, invalidation, date validation, list, CLI

Full pipeline (consolidator + NER extraction + multi-signal retrieval) deferred to Q3 2026 per 22h estimate.

## Tests: 7 passed
