---
type: feature
spec: SPEC-188
date: 2026-06-24
title: "SPEC-188 F3+F4 complete — Decision Trace + Fix Survival"
---

### Added — SPEC-188 F3 complete — Causal Confidence Channel + Decision Trace (P5)

- `scripts/decision-trace-writer.py`: CLI that writes structured JSON decision trace
  artefacts to `output/decision-traces/`. Fields: ts, agent, decision, rationale,
  confidence [0,1], alternatives, causal_chain, spec_ref. Feature flag:
  `SAVIA_DECISION_TRACE=on` (default off).
- `.opencode/hooks/decision-trace-capture.sh`: PostToolUse hook that detects
  architectural decision keywords in agent output (decidí, elegí, recomiendo,
  descarto, decided, chose, recommend, discard) and calls the writer. Always
  exits 0. Respects `SAVIA_DECISION_TRACE` master switch.
- `tests/test-causal-confidence-channel.bats`: 10 BATS tests covering JSON
  validity, directory creation, confidence range validation, alternatives field,
  hook existence, flag-off behaviour, required fields.
- `docs/rules/domain/decision-trace-protocol.md`: Protocol doc — when to write
  traces, JSON format, CLI reference, integration with failure-pattern-memory
  and Code Review Court.

### Added — SPEC-188 F4 complete — Fix Survival Check + Monthly Report (P4)

- `scripts/fix-survival-check.sh`: Weekly cron script that scans git log for
  fix commits in the last N days, detects reverts, computes survival_rate.
  CLI: `bash scripts/fix-survival-check.sh [--days 7] [--json] [--branch main]`.
  JSON output: week, checked_at, days_back, fixes_total, fixes_survived,
  survival_rate, reverted[].
- `scripts/monthly-diagnostic-report.sh`: Aggregates diagnostic-metrics-tracker,
  failure-pattern-memory stats, and fix-survival into a monthly Markdown report
  at `output/reports/diagnostic-YYYY-MM.md`.
  CLI: `bash scripts/monthly-diagnostic-report.sh [--month YYYY-MM]`.
- `tests/test-spec188-f4-survival.bats`: 10 BATS tests covering existence,
  JSON validity, survival_rate range, required fields, reverted array type,
  report generation, required sections, zero-commits edge case, frontmatter.
- `output/decision-traces/` and `output/reports/` directories created.
