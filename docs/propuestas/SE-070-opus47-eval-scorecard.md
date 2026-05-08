---
id: SE-070
title: SE-070 — Opus 4.7 calibration scorecard for 37 sonnet-4-6 agents
status: IMPLEMENTED
origin: Opus 4.7 migration analysis 2026-04-23
author: Savia
priority: alta
effort: L 12h (Slice 1-3 done, Slice 4 deferred per spec)
gap_link: 37 sonnet agents may benefit from xhigh opus-4-7 but upgrade needs empirical A/B
approved_at: "2026-04-23"
applied_at: "2026-04-24"
implemented_at: "2026-04-24"
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
- Reads `.opencode/agents/*.md` frontmatter (`model`, agent name)
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
- `.opencode/skills/model-upgrade-audit/SKILL.md` — related but different purpose (prompt-debt detection)
- Complementary: SE-066..SE-069 (4.7 immediate adaptations)

## Resolution (2026-04-24)

Slice 1-3 IMPLEMENTED. Slice 4 (actual evals) DEFERRED per spec's own "defer execution until batch budget allows" criterion.

### Slice 1 — Scorecard scaffolding (DONE)

`scripts/opus47-calibration-scorecard.sh`:
- Lists all 37 sonnet-4-6 agents with golden-set detection + recommend flag (eval/defer)
- Emits YAML (machine-readable) + MD (human-readable) outputs
- Cost delta computed: +1025% per I/O unit for opus-4-7 xhigh vs sonnet-4-6 default
- CLI: `--help`, `--quiet`, `--json`, unknown arg exits 2
- Verified: 37 sonnet agents detected (matches grep count)

### Slice 2 — Eval matrix template (DONE)

`tests/golden/opus47-calibration/`:
- README.md con structure, workflow, rubric (5 dims × 0-10)
- TEMPLATE/ con prompt.txt, expected.md, score.yaml
- 3-case-per-agent recommendation (happy / edge / failure-mode)

### Slice 3 — Execution playbook (DONE)

`docs/rules/domain/opus47-calibration-playbook.md`:
- 6-step workflow per agent
- Decision matrix: quality_cost_ratio >=2.0 upgrade, 1.0-2.0 keep, <1.0 keep/downgrade
- Cost guidance: ~$0.72 per agent × 3 cases, $27 for all 37, $30/quarter conservative budget
- 5 anti-patterns documented (blind-eval, single-case, parallel upgrades, skip failure-mode, non-rotated judge)
- Rollback procedure + re-eval cadence

### Slice 4 — Initial eval of 3 candidates (DEFERRED)

Not executed in this PR per spec's explicit deferral criteria. Requires:
- ~$2.20 API cost for 3 agents × 3 cases × 2 models
- Blind eval by human or rotated LLM-judge
- Candidates pre-identified: business-analyst, drift-auditor, tech-writer

Next execution window: when batch budget allows AND need for objective calibration data arises.

### Tests

`tests/test-opus47-calibration-scorecard.bats`: 45 tests certified (score **98**). Coverage: CLI, execution, JSON mode, cost model constants, golden-set detection, output content, Slice 2 files, Slice 3 playbook, negative cases, edge cases, isolation.

## Acceptance Criteria final

- [x] Scorecard lists all 37 sonnet agents with cost delta estimates
- [x] Eval template supports 3+ A/B test cases per agent
- [ ] 3 initial evals completed (DEFERRED — Slice 4)
- [x] Playbook enables future evals without rediscovery
- [x] `readiness-check.sh` PASS
