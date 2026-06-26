## SE-025 — Agentic Workforce Analytics

### Added

- `scripts/workforce-analytics.py` — Python module that aggregates agent data sources
  (`data/agent-actuals.jsonl`, `output/agent-trace/*.jsonl`, `output/**/*.review.crc`) into
  workforce metrics: `agent_invocations`, `avg_durations`, `success_rates`, `most_active_hours`,
  `top_agents`, `review_court` pass rate, `summary`. Supports `--since` date filter.

- `scripts/workforce-analytics.sh` — CLI wrapper: `--json`, `--format table|json|csv`,
  `--since YYYY-MM-DD`. Falls back to jq if python3 unavailable. Returns
  `{metrics:{}, note:"no agent data found"}` when no data present.

- `docs/rules/domain/workforce-analytics-protocol.md` — Protocol doc: metrics table,
  how to run, interpretation guide, privacy policy (aggregate-only, N4b for individuals).

- `tests/scripts/test_workforce_analytics.py` — 17 pytest tests covering empty/synthetic data,
  invocation counts, avg duration calculation, success rate range, top_agents ordering,
  JSON serializability, since-filter, review_court key presence.

- `tests/bats/test-spec-se-025-analytics.bats` — 10 BATS tests: script exists/executable,
  JSON output valid, no-data graceful, protocol.md present, csv header, since-filter,
  synthetic data key checks, table output.

### Status

`SPEC-SE-025`: PROPOSED → IMPLEMENTED
