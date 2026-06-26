---
context_tier: L3
token_budget: 900
resource: internal://docs/rules/domain/tribunal-execution.md
spec: SE-106
---

# Tribunal Execution Policy (SE-106)

## Model

Three tribunals; two execution models:

| Tribunal | Model | Reason |
|---|---|---|
| Truth Tribunal | Tiered (Tier 0 seq -> Tier 1 parallel) | Async, no latency SLA; optimize tokens |
| Code Review Court | Tiered (Tier 0 seq -> Tier 1 parallel) | Async, no latency SLA; optimize tokens |
| Recommendation Tribunal | Full parallel always | Sync, p95 < 3s SLA; incompatible with sequential |

## Tiered Model

**Tier 0**: sequential, early-stop on first VETO. Ordered by veto probability x tokens-saved.

**Tier 1**: parallel fan-out. Only executed if Tier 0 PASS.

Invocation: `bash scripts/tribunal-tiered-runner.sh --tribunal truth|court --draft <file>`

## Config

```bash
SAVIA_TIERED_TRIBUNAL=on|off         # default off (pilot)
SAVIA_TIERED_TRUTH_TIER0=compliance-judge,hallucination-judge,factuality-judge
SAVIA_TIERED_COURT_TIER0=security-judge,correctness-judge
TRIBUNAL_FORCE_FULL_PANEL=1          # disable tiered, run all judges in parallel
```

## Tier 0 judge order

**Truth Tribunal**:
1. compliance-judge (PII/N-tier leak, regulatory absolute veto)
2. hallucination-judge (fabrications confidence >= 0.8)
3. factuality-judge (claims contradicted by evidence)

**Code Review Court**:
1. security-judge (OWASP/credentials, merge blocker)
2. correctness-judge (broken logic/tests)

## Savings

| Tribunal | VETO rate | Tokens saved/veto | Monthly estimate |
|---|---|---|---|
| Truth | ~15% | ~78k | ~1.2M tok/month |
| Court | ~10% | ~15k | ~300k tok/month |

PASS runs: no token savings. Latency increases ~15-25% on PASS (Tier 0 serial before Tier 1 starts).

## Schema

`.truth.crc` and `.review.crc` gain optional fields (backward-compat; absent = legacy parallel):

```yaml
execution_mode: tiered
tier_0:
  judges_run: [...]
  stopped_at: <judge or null>
  verdict: PASS or VETO
tier_1:
  judges_run: [...]
  execution: parallel or skipped
tokens_saved_vs_parallel: N
```

## Override

TRIBUNAL_FORCE_FULL_PANEL=1 bypasses tiered, runs full panel in parallel.
Use for: external audits, calibration, debug, A/B measurement.

## Telemetry

All runs appended to output/tiered-tribunal-telemetry.jsonl:
  {ts, tribunal, exec_mode, tier0_verdict, tier1_skipped, tokens_saved, judges_run}
