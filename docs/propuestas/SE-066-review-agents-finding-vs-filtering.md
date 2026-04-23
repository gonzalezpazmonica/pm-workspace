---
id: SE-066
title: SE-066 — Review agents finding-vs-filtering separation for Opus 4.7
status: IMPLEMENTED
origin: Opus 4.7 migration analysis 2026-04-23
author: Savia
priority: Alta
effort: S 4h
gap_link: Opus 4.7 follows filter instructions more literally → recall drop on code review
approved_at: "2026-04-23"
applied_at: "2026-04-23"
batches: [31]
expires: "2026-05-23"
era: 186
---

# SE-066 — Review agents finding-vs-filtering separation

## Purpose

Opus 4.7 is measurably better at bug-finding (+11pp recall on Anthropic's hardest eval) but follows filtering instructions more literally than 4.6. Prompts that say "only report high-severity" or "be conservative" now cause the model to investigate thoroughly, identify bugs, and silently drop findings below the bar. Net effect: measured recall drops despite better underlying capability.

19 review/judge/auditor agents in Savia currently combine finding and filtering in one prompt. Under 4.7 this produces fewer reported findings than 4.6 on the same code.

## Affected agents

`code-reviewer`, `pr-agent-judge`, `security-judge`, `correctness-judge`, `spec-judge`, `cognitive-judge`, `architecture-judge`, `calibration-judge`, `coherence-judge`, `completeness-judge`, `compliance-judge`, `factuality-judge`, `hallucination-judge`, `source-traceability-judge`, `security-auditor`, `confidentiality-auditor`, `drift-auditor`, `court-orchestrator`, `truth-tribunal-orchestrator`.

## Scope

### Slice 1 — Standardized "coverage first" section (S, 3h)

Append to each affected agent's system prompt a standardized block:

```
## Reporting Policy

Report every issue you identify, including low-confidence and low-severity
findings. Your goal is COVERAGE, not filtering. Do not suppress findings
you judge to be borderline — surface them and attach:

- confidence: {low, medium, high}
- severity: {info, low, medium, high, critical}

A downstream filter will rank and prune. It is better to surface a finding
that later gets filtered out than to silently drop a real bug.
```

### Slice 2 — Validation script + BATS (S, 1h)

`scripts/opus47-compliance-check.sh` — asserts the pattern exists in each listed agent. BATS test invokes and validates.

## Acceptance criteria

- 19 agents contain `## Reporting Policy` block with coverage-first language
- `scripts/opus47-compliance-check.sh --finding-vs-filtering` returns 0
- BATS test covers at least 5 representative agents
- Zero regression: `scripts/readiness-check.sh` PASS

## Risks

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| More noise in downstream review pipeline | Alta | Medio | Pipeline already has ranking/filtering step; confidence field enables auto-sort |
| Prompt bloat reduces instruction attention | Media | Bajo | Block is 8 lines, placed in dedicated section |
| Agents not used with 4.7 penalized | Baja | Bajo | Pattern is neutral under 4.6 |

## Referencias

- Opus 4.7 migration analysis 2026-04-23
- Anthropic Opus 4.7 release notes (code review recall +11pp but stricter instruction following)
- Complementary: SE-067 (subagent fan-out), SE-068 (XML tags)
