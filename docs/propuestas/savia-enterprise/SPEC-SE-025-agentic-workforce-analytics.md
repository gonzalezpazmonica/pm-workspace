---
status: PROPOSED
---

# SPEC-SE-025 — Agentic Workforce Analytics

> **Priority:** P0 · **Estimate (human):** 8d · **Estimate (agent):** 8h · **Category:** complex · **Type:** human-agent productivity measurement + cost accounting + quality delta

## Objective

Give a 5000-person consultancy a **transparent, auditable measurement
system** for the agentic workforce: how much work agents do vs humans,
what it costs, what quality delta it produces, and when clients should
be told that AI assisted their project. This is not a dashboard bolted
onto a PSA — it is the accounting layer that makes the ~10x throughput
claim from SE-013 (dual estimation) verifiable with real data.

No consultancy has this today. The industry tracks developer productivity
with DORA metrics. Nobody tracks the productivity of the human+agent
hybrid team that is becoming the reality of 2026 software delivery.
The EU AI Act (Article 14, Article 52) requires transparency about AI
involvement in high-risk decisions — and for regulated clients, any
AI-generated code is potentially a high-risk artifact.

Savia Enterprise is uniquely positioned to provide this: every agent
invocation already produces structured traces (`agent-trace-log.sh`),
every PR has a `Co-Authored-By: Claude` trailer, and the dual estimation
rule (SE-013) tracks predicted vs actual agent hours. SE-025 turns these
data points into actionable intelligence.

## Principles affected

- **#3 Honestidad radical** — if agents produce worse code than humans in a category, the analytics show it. No sugar-coating.
- **#4 Privacidad absoluta** — individual developer productivity is N4b (PM-only). Aggregate team data is N4 (project level). No individual performance ranking visible to peers.
- **#5 El humano decide** — analytics inform decisions; they don't auto-assign or auto-evaluate.

## Design

### Data sources (already exist in pm-workspace)

| Source | What it provides | Location |
|--------|-----------------|----------|
| `agent-trace-log.sh` | Agent invocations with duration, model, tokens | `output/agent-trace/` |
| `data/agent-actuals.jsonl` | Predicted vs actual agent hours per spec | `data/` |
| `.review.crc` files | Court verdicts — agent code quality scores | per-PR |
| git log `Co-Authored-By` | Which commits had agent involvement | git history |
| `estimate-convert.sh` | Human-days to agent-hours conversion | `scripts/` |
| PR cycle time | Time from branch creation to merge | git + GitHub API |

### Analytics structure

```
tenants/{tenant-id}/analytics/
├── workforce-dashboard.yaml   # Current period aggregate metrics
├── periods/
│   ├── 2026-Q2.yaml          # Quarterly aggregate
│   ├── 2026-04.yaml          # Monthly detail
│   └── ...
├── cost-model.yaml            # Token costs, hourly rates, cost comparison
└── transparency-log.jsonl     # AI involvement disclosures per project
```

### Core metrics

#### 1. Throughput ratio (agent vs human)

```yaml
throughput:
  period: "2026-04"
  specs_completed: 14
  specs_by_agent_primary: 11       # agent did >50% of implementation
  specs_by_human_primary: 3
  avg_wallclock_hours_agent: 1.8   # from agent-actuals.jsonl
  avg_wallclock_hours_human: 12.5  # from timesheet
  speedup_empirical: 6.9           # = 12.5 / 1.8
  speedup_conservative: 10.0       # SE-013 conservative ratio
  delta: "-31%"                    # empirical is 31% slower than conservative
  interpretation: "Conservative estimate is optimistic for this team. Recalibrate."
```

#### 2. Cost comparison

```yaml
cost:
  period: "2026-04"
  agent_cost:
    total_tokens: 12_500_000
    token_cost_eur: 187.50         # at Anthropic pricing
    compute_cost_eur: 0            # Ollama fallback hours
    total_eur: 187.50
  human_equivalent_cost:
    hours_saved: 118               # agent wallclock × speedup
    blended_rate_eur: 85           # loaded cost per hour
    total_eur: 10_030.00
  roi: 53.5                       # = human_equivalent / agent_cost
  cost_per_spec_agent: 17.05      # 187.50 / 11 specs
  cost_per_spec_human: 3_343.33   # (3 specs × 12.5h × 85) / 3
```

#### 3. Quality delta

```yaml
quality:
  period: "2026-04"
  agent_generated:
    prs_reviewed: 11
    avg_court_score: 78            # from .review.crc
    critical_findings: 3
    high_findings: 7
    fix_rounds_avg: 1.4
  human_generated:
    prs_reviewed: 3
    avg_court_score: 85
    critical_findings: 0
    high_findings: 2
    fix_rounds_avg: 0.3
  delta:
    score_gap: -7                  # agent scores 7 points lower
    critical_gap: "+3"             # agent has 3 more criticals
    interpretation: "Agent code is faster but needs more review rounds.
      The Court catches issues before merge. Net quality is acceptable
      but not superior."
```

#### 4. Transparency disclosure

For regulated clients or contracts requiring AI transparency:

```yaml
# transparency-log.jsonl (append-only)
{"project": "erp-migration", "period": "2026-04", "disclosure_level": "full",
 "agent_contribution_pct": 78, "specs_agent_primary": 8, "specs_total": 10,
 "models_used": ["claude-opus-4-6", "claude-sonnet-4-6"],
 "court_reviewed": true, "human_e1_approved": true,
 "ai_act_classification": "high-risk", "client_notified": true,
 "notification_date": "2026-04-01", "notification_method": "SOW amendment"}
```

### Disclosure levels

| level | when | what client sees |
|-------|------|-----------------|
| `none` | No regulatory requirement, no contractual clause | Nothing — internal only |
| `aggregate` | Contract mentions "AI-assisted development" | "AI tools assisted N% of development" |
| `full` | DORA/NIS2 client, AI Act high-risk, contractual requirement | Per-spec breakdown, models used, Court scores, human approval chain |

### New agents

| agent | level | purpose |
|-------|-------|---------|
| `workforce-analyst` | L1 | Computes throughput/cost/quality metrics from existing data sources |
| `transparency-reporter` | L1 | Generates disclosure reports for clients per contract requirements |
| `calibration-advisor` | L1 | Compares empirical speedup vs conservative, suggests SE-013 recalibration |

### New commands

| command | output |
|---------|--------|
| `/workforce-dashboard [--period 2026-04]` | Throughput + cost + quality dashboard |
| `/agent-roi [--project X]` | Agent ROI calculation for a project or tenant |
| `/quality-delta [--period X]` | Agent vs human quality comparison |
| `/transparency-report PROJECT` | AI involvement disclosure for a client |
| `/calibrate-speedup` | Trigger SE-013 empirical recalibration |

### Events

```json
{"event": "workforce.period_computed", "period": "2026-04", "speedup": 6.9, "roi": 53.5}
{"event": "workforce.quality_alert", "delta_score": -7, "interpretation": "agent code needs more review"}
{"event": "transparency.disclosure_generated", "project": "erp-migration", "level": "full"}
{"event": "calibration.recommended", "current_conservative": 10, "empirical": 6.9, "samples": 14}
```

## Acceptance criteria

1. Regla `docs/rules/domain/agentic-workforce.md` ≤150 lines.
2. `workforce-analyst` computes throughput from `agent-actuals.jsonl` + git log.
3. Cost comparison uses real Anthropic pricing for token costs.
4. Quality delta reads `.review.crc` files and computes agent vs human scores.
5. `/transparency-report` generates a client-ready disclosure at 3 levels (none/aggregate/full).
6. Disclosure log is append-only JSONL with AI Act required fields.
7. Calibration advisor triggers when empirical speedup deviates >20% from conservative.
8. Individual developer data is N4b (not visible to peers or in aggregate reports).
9. Equality Shield counterfactual test applied to any per-person metric comparison.
10. 20+ BATS tests, SPEC-055 ≥ 80.
11. Air-gap capable. `pr-plan` 11/11.

## Out of scope

- Real-time token cost tracking during agent execution (post-hoc only for v1).
- Client-facing web dashboard (internal CLI reports for v1).
- Automated contract amendment for AI disclosure (manual process).
- Competitive benchmarking against non-Savia teams.
- Agent performance optimization (tuning models/prompts based on quality data — future).

## Dependencies

- **Blocked by:** SE-001, SE-013 (dual estimation provides the data model), SE-021 (Court provides quality scores).
- **Integrates with:** SE-018 (billing uses ROI for pricing), SE-019 (evaluation includes agent contribution %), SE-022 (resource management accounts for agent capacity).
- **Soft deps:** SE-006 (governance for AI Act compliance framework), SE-017 (SOW may require transparency clause).

## Migration path

- Feature-flag `AGENTIC_WORKFORCE_ANALYTICS_ENABLED=false`.
- No import needed — reads existing data sources.
- Coexistence: without the flag, no analytics computed.

## Impact statement

The question "was the AI worth it?" will be asked by every CFO, every
client, and every regulator within 12 months. A consultancy that can
answer with data — specific throughput ratios, cost comparisons, quality
deltas, and auditable transparency disclosures — wins the trust war.
Savia Enterprise is the only workspace that has all the raw data
(agent traces, Court verdicts, dual estimation actuals, git authorship)
already flowing. SE-025 is the analytics layer that makes the invisible
visible.

## Sources

- EU AI Act (2024) — Article 14 (human oversight), Article 52 (transparency)
- DORA (EU 2022/2554) — ICT third-party risk, applicable to AI service providers
- METR research papers on AI agent productivity (arxiv 2503.14499, 2507.09089)
- Savia SE-013 dual estimation rule (conservative 10x + empirical)
- Anthropic API pricing (2026 rates for input/output/cache tokens)
- Google DORA metrics framework (adapted for human+agent teams)
