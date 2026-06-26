---
context_tier: L2
token_budget: 800
---

# Workforce Analytics Protocol (SE-025)

## What it measures

SE-025 aggregates existing agent data sources into actionable metrics for the
human+agent hybrid team. Data stays local; nothing is sent externally.

### Metrics generated

| Metric | Source | Meaning |
|---|---|---|
| `agent_invocations` | `data/agent-actuals.jsonl`, `output/agent-trace/*.jsonl` | Total runs per agent |
| `avg_duration_min` | `duration_s` field in traces | Mean duration in minutes per agent |
| `success_rate` | `run_status == "completed"` | Fraction of runs without errors (0-1) |
| `review_court_pass_rate` | `output/**/*.review.crc` | PRs passing Court on first review |
| `most_active_hour` | `started_at` timestamps | Hour of peak activity (0-23, UTC) |
| `top_agents` | Aggregated invocations | Top 5 agents by run count |

## How to run

```bash
# Human-readable table (default)
bash scripts/workforce-analytics.sh

# JSON output
bash scripts/workforce-analytics.sh --json

# Filter by date
bash scripts/workforce-analytics.sh --since 2026-01-01

# CSV export
bash scripts/workforce-analytics.sh --format csv

# Python module directly
python3 scripts/workforce-analytics.py --data-dir output/ --repo-root .
```

## Interpreting the output

- **success_rate < 0.8**: agent is failing frequently — check task spec quality
- **avg_duration_min > 10**: agent is taking long — check tool call depth
- **review_court_pass_rate < 0.7**: agent output needs more review cycles
- **no agent data found**: no `data/agent-actuals.jsonl` or trace logs yet — run
  at least one agent task and ensure `agent-trace-log.sh` is active

## Data privacy

All metrics are aggregate. Individual developer data is N4b (PM-only) per SE-025
Principle #4 (Privacidad absoluta). No per-person performance rankings are
produced. Aggregate team data is N4 (project level).

## Feature flag

`AGENTIC_WORKFORCE_ANALYTICS_ENABLED` controls the feature.
Default: reads data if present; no active data collection.

## Sources

- `output/agent-trace/*.jsonl` — agent trace logs (schema_version 2)
- `data/agent-actuals.jsonl` — predicted vs actual agent hours (SE-013)
- `output/**/*.review.crc` — Court verdicts per PR (SE-021)
