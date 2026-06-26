# Truth Tribunal — Tiered Execution Reference (SE-106)

When `SAVIA_TIERED_TRIBUNAL=on`, invoke `scripts/tribunal-tiered-runner.sh` instead of launching all 7 judges in parallel:

```bash
bash scripts/tribunal-tiered-runner.sh \
  --tribunal truth \
  --draft <report_path> \
  --mode sequential-first \
  --tier0-judges compliance-judge,hallucination-judge,factuality-judge \
  --tier1-judges source-traceability-judge,coherence-judge,calibration-judge,completeness-judge
```

## Tier 0 (sequential, early-stop on veto)

| Order | Judge | Model | Reason |
|---|---|---|---|
| 1 | compliance-judge | heavy | PII/N-tier leak — regulatory absolute veto |
| 2 | hallucination-judge | heavy | Fabrications confidence >=0.8 |
| 3 | factuality-judge | heavy | Claims contradicted by evidence |

If any Tier 0 judge emits VETO: run terminates immediately, Tier 1 skipped.
Estimated tokens saved on veto: ~78k (67% reduction vs full parallel run).

## Tier 1 (parallel fan-out — only if Tier 0 PASS)

Judges run simultaneously: source-traceability-judge, coherence-judge, calibration-judge, completeness-judge.

## Schema addendum (backward-compat fields)

execution_mode: tiered or parallel (legacy default if absent)
tier_0: judges_run, stopped_at (null if PASS), verdict
tier_1: judges_run, execution ("parallel" or "skipped")
tokens_saved_vs_parallel: 78000

## Override

TRIBUNAL_FORCE_FULL_PANEL=1 disables tiered, runs all 7 judges in parallel.
Use for: external audits requiring full panel, calibration A/B testing, debug.

Ref: docs/rules/domain/tribunal-execution.md (SE-106).
