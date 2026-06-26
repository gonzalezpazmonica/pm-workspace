## SPEC-123 — Graphiti Temporal Pattern in KG (2026-06-24)

### Added
- `scripts/knowledge-graph-temporal.py`: standalone temporal extension module for Savia knowledge graph
- Adds `valid_at` (ISO-8601) and `expired_at` (ISO-8601, nullable) columns to entities table (idempotent migration)
- `add-temporal`: adds/updates temporal metadata for an entity with validation
- `invalidate`: sets `expired_at` on an entity (soft-delete, never hard-deletes)
- `query-at --when DATE`: filters entities valid at a given point in time (null-safe — entities without temporal metadata are always included)
- `backfill`: sets `valid_at=first_seen` for legacy entities with null valid_at (AC-03)
- Validator rejects invalid ISO-8601 and expired_at < valid_at (Contradict guard)
- Compatible with existing knowledge-graph.py SQLite schema
- `tests/scripts/test_graphiti_temporal.py`: 8 pytest tests covering all operations + edge cases
