## SPEC-108 — Agent RCA Analyzer (2026-06-24)

### Added
- `scripts/agent-rca-analyzer.py`: lightweight agent Root Cause Analysis pipeline (no Sentry required)
- Builds on `semantic-fault-handlers.py` for error classification; falls back to keyword matching
- RCA layer mapping: LOGIC→SPEC_REVIEW, CAPACITY→CONTEXT_PRUNING, SCOPE→TASK_DECOMPOSITION,
  FORMAT→PROMPT_FIX, VALIDATION→AC_REVIEW, TRANSIENT→RETRY
- Output JSON: `{root_cause, category, fix_suggestion, confidence, rca_layer}`
- Confidence reduced when no context provided (0.85x multiplier)
- `tests/scripts/test_agent_rca.py`: 10 pytest tests covering all categories, fields, CLI
