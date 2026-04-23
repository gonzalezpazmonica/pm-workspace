---
id: SE-070
title: SE-070 — Opus 4.7 calibration scorecard for 37 sonnet-4-6 agents
status: PROPOSED
origin: Opus 4.7 migration analysis 2026-04-23
author: Savia
priority: Baja
effort: L 12h (deferred execution)
gap_link: 37 sonnet agents may benefit from xhigh opus-4-7 but upgrade needs empirical A/B
approved_at: "2026-04-23"
applied_at: null
expires: "2026-06-23"
era: 186
---

# SE-070 — Opus 4.7 calibration scorecard

## Purpose

Savia runs 37 agents on `claude-sonnet-4-6` as cost-conservative default. Some of these (business-analyst, azure-devops-operator, tech-writer, drift-auditor, etc.) might produce meaningfully better output on `claude-opus-4-7` at `effort: xhigh` with acceptable cost increase. Others are legitimate cheap-tier (digestors, utility automation) where upgrade is waste.

Without evaluation, we can't tell which is which. Mass upgrade = wasted tokens. No upgrade = leaving quality on the table. This proposal creates the scorecard infrastructure; execution is deferred until evals are funded.

## Scope

### Slice 1 — Scorecard scaffolding (S, 3h)

`scripts/opus47-calibration-scorecard.sh`:
- Reads `.claude/agents/*.md` frontmatter (`model`, agent name)
- For each sonnet-4-6 agent, lookup golden-set tests if available
- Emit YAML scorecard: `output/opus47-calibration-{date}.yaml` with columns:
  - agent, current_model, estimated_cost_delta_xhigh, has_golden_set, recommend_eval

### Slice 2 — Eval matrix template (S, 3h)

`tests/golden/opus47-calibration/` — template set of A/B test pairs:
- Same input to sonnet-4-6 vs opus-4-7 xhigh
- Score output on quality (human judge or programmatic eval)
- Track token cost delta

### Slice 3 — Execution playbook (S, 3h)

`docs/rules/domain/opus47-calibration-playbook.md`:
- How to run A/B for a single agent
- Decision matrix: quality gain % vs cost % → upgrade/keep/downgrade
- Examples from evaluated agents

### Slice 4 — Initial eval of 3 candidate agents (M, 3h)

Run A/B on 3 high-leverage candidates:
- `business-analyst` (strategic analysis)
- `drift-auditor` (pattern-heavy)
- `tech-writer` (long-form output)

Document results and decide upgrade-or-keep.

## Acceptance criteria

- Scorecard script lists all 37 sonnet agents with cost delta estimates
- Eval template supports 3+ A/B test cases per agent
- 3 initial evals completed with upgrade recommendation
- Playbook enables future evals without rediscovery
- `readiness-check.sh` PASS

## Risks

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Eval methodology biased toward opus | Alta | Alto | Use LLM-as-judge with blind A/B; rotate judge model |
| Cost of running evals exceeds benefit | Media | Medio | Deferred execution; run only when batch budget allows |
| Results don't generalize across agents | Alta | Medio | Per-agent decision, not category-wide |
| Opus 4.8 ships before evals complete | Media | Bajo | Framework is model-agnostic, re-runnable |

## No hacen

- Does NOT auto-upgrade any agent (human decision per scorecard)
- Does NOT run evals in Slice 1-3 — only scaffolds infrastructure
- Does NOT retire sonnet-4-6 as an option

## Prioridad

Baja porque:
- No blocking issue (current system works)
- Upgrade cost > wasted on wrong calls
- Framework infrastructure is reusable for future model releases (4.8, 5.0)
- Can be executed opportunistically across multiple sprints

## Referencias

- Opus 4.7 migration analysis 2026-04-23
- Current agent count: 25 opus-4-7 / 37 sonnet-4-6 / 3 haiku-4-5
- `.claude/skills/model-upgrade-audit/SKILL.md` — related but different purpose (prompt-debt detection)
- Complementary: SE-066..SE-069 (4.7 immediate adaptations)
