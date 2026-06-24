---
name: truth-tribunal-runbook
description: operational runbook for multi-judge evaluation orchestration
summary: Runbook for the truth-tribunal agent (SE-099). Judges, veto logic, output schema, iteration loop.
maturity: stable
context: fork
context_cost: medium
---

# Truth Tribunal Orchestrator — Runbook

## The 7 Judges

| Judge | Model | Focus |
|---|---|---|
| factuality-judge | opus | Claims verifiable vs sources |
| source-traceability-judge | sonnet | Citations present and resolvable |
| hallucination-judge | opus | No invented entities or numbers |
| coherence-judge | sonnet | Internal consistency |
| calibration-judge | sonnet | Confidence proportional to evidence |
| completeness-judge | sonnet | Delivers what title promises |
| compliance-judge | opus | Privacy levels, format, regulatory |

Weights per report type: `docs/rules/domain/truth-tribunal-weights.md`.
Profiles: default, executive, compliance, audit, digest, subjective.

## Scoring and Verdicts

Score 0-100 using profile weights. Thresholds:
- PUBLISHABLE: ≥90, zero vetos
- CONDITIONAL: 70-89 — human decides
- ITERATE: <70 or any veto — feedback to generator
- ESCALATE: after 3 ITERATE cycles
- NOT_EVALUABLE: 4+ judges abstain — escalate human

## Veto Rules (absolute)

Single veto from any judge blocks publication:
- compliance-judge: privacy-level violation or token/key in N1 path
- hallucination-judge: fabricated claim confidence ≥0.8
- factuality-judge: contradicted claim with evidence
- coherence-judge: critical arithmetic error or direct contradiction
- source-traceability-judge: audit output with uncited claim

## Output: `.truth.crc`

YAML file written next to the evaluated report:

```yaml
tribunal_id: "TT-{YYYYMMDD-HHMMSS}"
report_path: "{path}"
report_type: "executive|compliance|audit|digest|subjective|default"
iteration: {N}
destination_tier: "N1|N2|N3|N4|N4b"
weighted_score: {0-100}
verdict: "PUBLISHABLE|CONDITIONAL|ITERATE|ESCALATE|NOT_EVALUABLE"
vetos: [{judge, reason}]
judges:
  factuality: {score, confidence, verdict, findings}
  source_traceability: {...}
  hallucination: {...}
  coherence: {...}
  calibration: {...}
  completeness: {...}
  compliance: {...}
aggregation: {abstentions, total_findings, critical_findings}
feedback_for_generator: "{structured findings — only when ITERATE}"
```

## Iteration Loop

When verdict is ITERATE:
1. Compile findings grouped by judge into markdown feedback
2. Return to caller with feedback and incremented iteration count
3. Caller decides whether to regenerate and re-invoke
4. After iteration 3 still ITERATE → force ESCALATE

## Anti-Patterns

- NEVER score the report yourself (orchestrate only)
- NEVER skip a judge (all 7 or escalate NOT_EVALUABLE)
- NEVER override a veto (absolute)
- NEVER cache verdict across versions
- NEVER deliver ITERATE to user

## Budget

- 7 parallel judges: ~7× per-agent budget; cap at 2× per-judge
- Typical wall-clock: 30-90s; timeout → NOT_EVALUABLE

## Fan-Out (SE-067 / SE-066 / SPEC-127)

- SE-067: parallel fork in one turn for independent items
- SE-066: each finding carries confidence + severity
- Fallback (SPEC-127 Slice 4): sequential inlined mode via
  `bash scripts/savia-orchestrator-helper.sh mode`
