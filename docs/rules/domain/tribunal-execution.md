---
context_tier: L3
token_budget: 900
---

# Tribunal Execution Policy — SE-106

> Canonical rule for tribunal orchestration mode selection.
> Applies to: truth-tribunal-orchestrator, court-orchestrator, recommendation-tribunal-orchestrator.

## Model

Two tribunals use **tiered hybrid** execution. One uses **parallel-only**.

| Tribunal | Mode | Reason |
|---|---|---|
| Truth Tribunal | Tiered hybrid | Async, token-savings outweigh latency cost |
| Code Review Court | Tiered hybrid | Async, merge-blocking judges identified |
| Recommendation Tribunal | Parallel only | Sync p95 < 3s SLA incompatible with sequential |

## Tiered Hybrid (Truth + Court)

### Tier 0 — sequential, early-stop on veto

Run judges in order. First VETO stops execution immediately. Tier 1 is skipped.

**Truth Tribunal Tier 0 order:** compliance-judge → hallucination-judge → factuality-judge

**Court Tier 0 order:** security-judge → correctness-judge

### Tier 1 — parallel fan-out (only if Tier 0 PASS)

All remaining judges run concurrently via Task fan-out.
Tier 0 verdicts are passed as context to Tier 1 judges.

**Truth Tribunal Tier 1:** source-traceability-judge, coherence-judge, calibration-judge, completeness-judge

**Court Tier 1:** architecture-judge, cognitive-judge, spec-judge (+ pr-agent-judge if opt-in)

## Override

`TRIBUNAL_FORCE_FULL_PANEL=1` — disables tiered, reverts to full parallel panel.

Use cases:
- External audit requiring complete panel even on veto
- Debug: see what all judges would have voted
- Calibration: measure inter-judge agreement

Mandatory: log override activation in audit trail.

## Helper

```bash
# Query tier assignment:
bash scripts/savia-orchestrator-helper.sh tier <tribunal_type>
# List judges with tier:
bash scripts/savia-orchestrator-helper.sh judges <tribunal_type>
```

`tribunal_type` values: `truth_tribunal` | `court` | `recommendation_tribunal`

## Schema additions (SE-106)

Both `.truth.crc` and `.review.crc` gain optional fields:

```yaml
execution_mode: "tiered"        # "parallel" if FORCE_FULL_PANEL; absent = "parallel" (backward-compat)
tier0_verdict: "PASS|VETO"
early_stopped: false
tokens_saved_vs_parallel: {N}  # 0 if PASS; estimated Tier1 tokens if early-stop
tier_0: {judges_run: [], stopped_at: null, stop_reason: null}
tier_1: {judges_run: [], execution: "parallel|skipped"}
```

## Expected savings

| Scenario | Saving |
|---|---|
| Truth VETO run (15% of runs) | ~67% tokens vs full panel |
| Court VETO run (10% of runs) | ~60% tokens vs full panel |
| Truth monthly (100 runs, 15% veto) | ~1.2M tokens/month |
| Court monthly (200 runs, 10% veto) | ~300k tokens/month |

## Recommendation Tribunal exception

Hard rule: 4 judges always parallel. Latency budget p95 < 3s sync.
Sequential would increase latency 3-4×. Token saving marginal (~6k/run).
`bash scripts/savia-orchestrator-helper.sh tier recommendation_tribunal` returns `{"tier0":[],"tier1":[...all...]}`.

## Source

SE-106 `docs/propuestas/SE-106-tiered-tribunal-execution.md`
