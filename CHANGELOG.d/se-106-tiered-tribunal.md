## SE-106 — Tiered tribunal execution

**Date**: 2026-06-24
**Status**: IMPLEMENTED

### What

Tiered hybrid execution model for Truth Tribunal and Code Review Court:

- **Tier 0**: judges run sequentially with early-stop on first VETO
- **Tier 1**: judges run in parallel fan-out, only if Tier 0 PASS
- **Recommendation Tribunal**: unchanged (always parallel, p95 < 3s SLA)

### Files added

- `scripts/tribunal-tiered-runner.sh` — orchestrator for tiered execution
- `docs/rules/domain/tribunal-execution.md` — execution policy rule
- `tests/scripts/test_tribunal_tiered.py` — 13 pytest tests
- `tests/bats/test-tribunal-tiered.bats` — 12 bats tests

### Files modified

- `.opencode/agents/truth-tribunal-orchestrator.md` — Tiered Execution section added
- `.opencode/agents/court-orchestrator.md` — Tiered Execution section added
- `.opencode/agents/recommendation-tribunal-orchestrator.md` — explicit NOT-tiered note added

### Config

```bash
SAVIA_TIERED_TRIBUNAL=on|off          # default off (pilot)
SAVIA_TIERED_TRUTH_TIER0=compliance-judge,hallucination-judge,factuality-judge
SAVIA_TIERED_COURT_TIER0=security-judge,correctness-judge
TRIBUNAL_FORCE_FULL_PANEL=1           # bypass tiered, force full panel
```

### Expected savings

| Tribunal | VETO rate | Tokens saved/veto | Monthly |
|---|---|---|---|
| Truth | ~15% | ~78k | ~1.2M tok/month |
| Court | ~10% | ~15k | ~300k tok/month |

### Telemetry

`output/tiered-tribunal-telemetry.jsonl` — one entry per run:
`{ts, tribunal, exec_mode, tier0_verdict, tier1_skipped, tokens_saved, judges_run}`
