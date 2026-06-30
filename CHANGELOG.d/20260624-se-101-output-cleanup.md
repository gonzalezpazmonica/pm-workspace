## SE-101 — Output directory retention policy (2026-06-24)

### Added
- scripts/output-cleanup.sh: retention policy enforcer for output/
  - Reads SAVIA_OUTPUT_RETENTION_DAYS (default: 90)
  - --dry-run (default): lists stale files without deleting
  - --execute: deletes stale files after interactive confirmation
  - Protected (never deleted): anti-adulation-telemetry.jsonl,
    quality-gate-history.jsonl, output/pentesting/, output/baselines/,
    cleanup-log-*.txt
  - Log: output/cleanup-log-YYYYMMDD.txt
- tests/bats/test-se-101-output-cleanup.bats: 3 tests (all pass)

### Notes
- 109 files currently older than 90 days in output/ (dry-run verified)
- Protected telemetry files confirmed excluded from candidate list
