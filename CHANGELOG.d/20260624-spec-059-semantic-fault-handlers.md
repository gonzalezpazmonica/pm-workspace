## SPEC-059 — Semantic Fault Handlers (2026-06-24)

### Added
- `scripts/semantic-fault-handlers.py`: Keyword-based error classifier for agent fault recovery
  - Categories: FORMAT, SCOPE, VALIDATION, TRANSIENT, CAPACITY, LOGIC
  - 40+ regex rules with per-rule weights for confidence scoring
  - Output JSON: `{category, confidence, suggested_handler, retry_strategy}`
  - Handler map: FORMAT→regenerate/immediate, TRANSIENT→retry/backoff, CAPACITY→decompose/none, LOGIC→escalate/none
  - CLI: `--error "text" [--context "additional context"]`
- `tests/scripts/test_semantic_fault_handlers.py`: 40 pytest tests

### Tests
- 40/40 passing — timeout→TRANSIENT, missing field→FORMAT, context exceeded→CAPACITY,
  AC-3 fails→VALIDATION, 50 files instead of 2→SCOPE, confidence in [0,1],
  TRANSIENT→retry, CAPACITY→decompose
