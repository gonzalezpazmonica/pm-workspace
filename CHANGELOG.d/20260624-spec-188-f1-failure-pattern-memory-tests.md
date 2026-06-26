## SPEC-188 Fase 1 — failure-pattern-memory.sh formal tests (2026-06-24)

### Added
- `tests/test-failure-pattern-memory.bats`: 8 bats tests formalizing SPEC-188 Fase 1 acceptance criteria:
  - AC-01: script exists and is executable
  - AC-02: `init` creates SQLite database with `failure_patterns` table
  - AC-03: `add` inserts a pattern (with feature flag enabled)
  - AC-04: `list` returns output without error
  - AC-05: `stats` returns structured text with total/open/acknowledged/resolved
  - AC-06: `SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=0` returns info message (disabled behavior)
  - AC-07: add + list round-trip — inserted pattern persists
  - AC-08: `stats` on uninitialised store does not crash

### Context
`scripts/failure-pattern-memory.sh` was implemented in SPEC-188 Fase 1 but lacked formal bats tests. The spec referenced `tests/test-failure-pattern-memory.bats` which did not exist. This entry closes that gap. Each test uses an isolated `$TEST_TMP` directory to avoid touching production `.claude/external-memory/failure-patterns/patterns.db`.
