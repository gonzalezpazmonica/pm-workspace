## SE-030 — GraphRAG Quality Gates: 12 structural checks (2026-06-24)

### Added
- `scripts/graphrag-quality-gates.sh`: wrapper over knowledge-graph.py SQLite DB executing 12 structural quality checks:
  1. No orphan nodes (entities with zero edges)
  2. No dangling edges (edges to non-existent nodes)
  3. Type consistency (entity types within known vocabulary)
  4. No exact duplicates (same name+type)
  5. Minimum entity count (warn if < 10)
  6. No self-loops (entity_a == entity_b)
  7. Basic connectivity (at least 1 edge exists)
  8. No empty required properties (name not NULL/blank)
  9. No future timestamps
  10. Reasonable size (warn if > 10000 nodes)
  11. Confidence scores in [0,1]
  12. Source/provenance field non-empty
  - Supports `--db PATH`, `--json`, `--quiet` flags
  - Exit 0 (PASS/WARN only), exit 1 (any FAIL)
  - Compatible with both source_id/target_id and entity_a/entity_b column schemas
- `tests/bats/test-se-030-graphrag-gates.bats`: 10 tests covering script existence, JSON output, 12-check count, missing DB handling, self-loop detection, confidence validation

### Notes
- Complements `graphrag-quality-gate.sh` (metric thresholds) with structural/topology checks
- Operates against `~/.savia/knowledge-graph.db` by default (SE-162)
