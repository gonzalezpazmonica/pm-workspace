---
id: SE-067
title: SE-067 — Orchestrator subagent fan-out + feasibility-probe adaptive thinking
status: IMPLEMENTED
origin: Opus 4.7 migration analysis 2026-04-23
author: Savia
priority: alta
effort: S 3h
gap_link: Opus 4.7 spawns fewer subagents + deprecates fixed budget_tokens
approved_at: "2026-04-23"
applied_at: "2026-04-23"
batches: [32]
expires: "2026-05-23"
era: 186
---

# SE-067 — Orchestrator fan-out + feasibility-probe adaptive thinking

## Purpose

Two unrelated-but-related changes collapse into one small batch:

**A. Orchestrator fan-out** — Opus 4.7 is more judicious about delegating to subagents. `dev-orchestrator`, `court-orchestrator`, `truth-tribunal-orchestrator` benefit from parallel fan-out but don't state it explicitly. Under 4.7, these orchestrators will spawn fewer subagents than intended unless instructions are explicit.

**B. feasibility-probe adaptive thinking** — `.opencode/skills/feasibility-probe/SKILL.md` default `budget_tokens: 50000`. Opus 4.7 replaces fixed budgets with adaptive thinking (`thinking: {type: "adaptive"}`). Skill must migrate.

## Scope

### Slice 1 — Orchestrator fan-out prompt (S, 1.5h)

Add to each of the 3 orchestrators a standardized block in their system prompt:

```
## Subagent Fan-Out Policy

Spawn multiple subagents in the SAME turn when fanning out across:
- Independent items (parallel items to audit/review/analyze)
- Multiple files needing the same analysis
- Judges/evaluators that must vote independently

Do NOT spawn a subagent for work you can complete directly in a single
response. Avoid serial 1-at-a-time spawning when parallel is possible.
```

### Slice 2 — feasibility-probe adaptive migration (XS, 0.5h)

Update `.opencode/skills/feasibility-probe/SKILL.md`:
- Remove `budget_tokens` parameter (line 36)
- Replace with adaptive thinking reference
- Preserve `budget_minutes` as time-box (orthogonal, still valid)

### Slice 3 — Validation + BATS (S, 1h)

`scripts/opus47-compliance-check.sh --fan-out` asserts orchestrators contain the block.
`scripts/opus47-compliance-check.sh --adaptive-thinking` asserts feasibility-probe migrated.

## Acceptance criteria

- 3 orchestrators contain `## Subagent Fan-Out Policy` block
- `feasibility-probe/SKILL.md` has no `budget_tokens` reference, documents adaptive thinking
- Compliance script exits 0 for both flags
- BATS tests cover fan-out detection + adaptive thinking detection
- Zero regression: `scripts/readiness-check.sh` PASS

## Risks

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Over-aggressive parallel spawning blows context budget | Media | Medio | Block explicitly says "NOT for work completable in single response" |
| Migration breaks existing feasibility probe runs | Baja | Medio | Adaptive is default in 4.7; regression covered by `readiness-check` |
| Orchestrator prompts grow past attention budget | Baja | Bajo | 7-line block, dedicated section |

## Referencias

- Opus 4.7 migration analysis 2026-04-23
- `.opencode/skills/feasibility-probe/SKILL.md`
- Complementary: SE-066 (finding-vs-filtering), SE-068 (XML tags)
