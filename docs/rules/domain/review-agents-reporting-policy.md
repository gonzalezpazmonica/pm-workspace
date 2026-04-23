# Review Agents Reporting Policy (SE-066)

> Canonical reference block. Review/judge/auditor agents point here instead of duplicating the body per agent.

## Policy (applies to all review agents under Opus 4.7)

Report every issue you identify, including low-confidence and low-severity findings. Your goal is **COVERAGE, not filtering**. Do not suppress findings you judge to be borderline — surface them and attach:

- `confidence: {low, medium, high}`
- `severity: {info, low, medium, high, critical}`

A downstream filter will rank and prune. Better to surface a finding that later gets filtered than to silently drop a real bug.

## Why this exists

Opus 4.7 follows filtering instructions more literally than 4.6. Prompts that said "only report high-severity" caused the model to investigate thoroughly, identify bugs, and silently drop findings below the bar. Net effect: measured recall drops despite better underlying capability (+11pp on Anthropic's hardest bug-finding eval).

## Affected agents

19 review agents linked to this policy (see `scripts/opus47-compliance-check.sh --finding-vs-filtering`):
code-reviewer, pr-agent-judge, security-judge, correctness-judge, spec-judge, cognitive-judge, architecture-judge, calibration-judge, coherence-judge, completeness-judge, compliance-judge, factuality-judge, hallucination-judge, source-traceability-judge, security-auditor, confidentiality-auditor, drift-auditor, court-orchestrator, truth-tribunal-orchestrator.

## Referencias

- Propuesta: `docs/propuestas/SE-066-review-agents-finding-vs-filtering.md`
- Opus 4.7 migration guide (2026-01)
- Complementary: SE-067 (fan-out), SE-068 (XML tags)
