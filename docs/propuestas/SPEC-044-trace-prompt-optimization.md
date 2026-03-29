# SPEC-044 — Trace-to-Prompt Optimization Loop

> Traces are collected but never used. This spec closes the loop:
> agent execution data feeds back into prompt improvement.

## Problem Statement

pm-workspace collects agent execution traces via `agent-trace-log.sh`
(PostToolUse hook). Each trace records agent name, token usage, duration,
outcome, and budget compliance in JSONL format. The `prompt-optimizer`
skill can improve agent prompts via AutoResearch loop with test fixtures.

The gap: these two systems are disconnected. Traces accumulate in
`projects/{p}/traces/agent-traces.jsonl` but are never analyzed to
identify which agents need optimization or what patterns cause failures.
The PM must manually notice degradation and manually trigger `/skill-optimize`.

Microsoft agent-lightning demonstrates that closed-loop trace-to-prompt
feedback reduces agent failure rates by 30-40% over 4 iterations.

## Architecture

Three components connected in a pipeline:

```
agent-trace-log.sh          trace-pattern-extractor       prompt-suggestion-engine
  (existing hook)      -->    (new script)            -->   (extends prompt-optimizer)
  JSONL per execution         Aggregates patterns           Generates optimization plan
                              Identifies candidates         Feeds into AutoResearch loop
```

### Component 1 — Trace Pattern Extractor

Script: `scripts/trace-pattern-extractor.sh`

Reads `agent-traces.jsonl` and computes per-agent metrics:

| Metric | Formula | Threshold |
|--------|---------|-----------|
| Failure rate | failures / total executions | > 20% = candidate |
| Budget overage rate | budget_exceeded / total | > 30% = candidate |
| Avg duration trend | moving avg last 10 vs prev 10 | > 50% increase = candidate |
| Token efficiency | tokens_out / tokens_in | < 0.05 = candidate (output too sparse) |

Output: `output/trace-analysis/agent-candidates.json` with ranked list.

### Component 2 — Pattern Classifier

For each candidate agent, classify the failure pattern:

| Pattern | Signal in traces | Prompt fix type |
|---------|-----------------|-----------------|
| Verbose output | tokens_out consistently > budget | Add output length constraint |
| Slow execution | duration_ms > 2x median | Reduce context loaded |
| Frequent failures | outcome=failure > 20% | Add error handling instructions |
| Budget blowout | budget_exceeded=true > 30% | Add budget awareness to prompt |
| Inconsistent quality | alternating success/failure | Add verification step |

Output: `output/trace-analysis/{agent}-patterns.json`

### Component 3 — Prompt Suggestion Engine

Extends the existing `prompt-optimizer` skill with trace-derived inputs:

1. Read pattern classification for the agent
2. Auto-generate a test fixture from recent trace data (reuse `auto-trigger.md` protocol)
3. Generate checklist items targeting identified patterns
4. Feed into existing AutoResearch loop (`/skill-optimize`)

Key difference from manual optimization: the checklist is data-driven,
not human-authored. Trace patterns map to specific checklist criteria.

## Data Flow

```
1. Agent executes (any subagent via Task tool)
2. agent-trace-log.sh appends JSONL (existing, unchanged)
3. /trace-optimize triggers analysis (new command, on-demand)
4. trace-pattern-extractor reads JSONL, computes metrics
5. Pattern classifier identifies failure types per agent
6. Suggestion engine generates fixture + checklist
7. prompt-optimizer runs AutoResearch loop
8. Output: {agent}.optimized.md + optimization log
9. PM reviews and adopts (or discards)
```

## Integration with Existing Systems

| System | Change | Detail |
|--------|--------|--------|
| `agent-trace-log.sh` | None | JSONL format already has all required fields |
| `prompt-optimizer` | Extend | Add `--from-traces` mode: skip manual fixture, use trace-derived checklist |
| `auto-trigger.md` | Complement | Add quantitative trace signals alongside PM correction signals |
| `agent-context-budget` | Read-only | Extractor reads `token_budget` from traces for overage rates |

Signal convergence: PM corrections (high confidence, 3+ in 10 runs) + trace
failure rate (medium, >20% in 20 runs) + budget overage (medium, >30% in 20 runs).
Combined signals from both sources yield very high confidence.

## New Command

`/trace-optimize [agent-name]`

- Without agent name: analyze all agents, show ranked candidates
- With agent name: run full pipeline for that specific agent
- Flag `--dry-run`: show analysis and recommendations without optimizing
- Flag `--auto`: skip confirmation, run optimization directly

## Metrics

| Metric | Measurement | Target |
|--------|------------|--------|
| Prompt improvement | G-Eval score before vs after AutoResearch loop | >= 1.5 point gain (0-10) |
| Token reduction | Avg tokens before vs after (next 10 runs) | >= 15% reduction |
| Accuracy delta | Failure rate before vs after (next 20 runs) | >= 10pp improvement |
| Optimization ROI | tokens_saved_per_run * runs / tokens_spent | > 3x within 2 sprints |

Track in: `output/trace-analysis/optimization-history.jsonl`

## Constraints

- NEVER auto-apply optimized prompts. PM always decides adoption
- NEVER modify agent-trace-log.sh (stable, async, zero-risk)
- Minimum 20 trace entries per agent before analysis (statistical floor)
- Maximum 1 trace-optimize suggestion per session (anti-spam)
- Reuse existing prompt-optimizer guardrails (no security rule changes,
  no frontmatter changes, .optimized.md output)

## Phases

**Phase 1**: trace-pattern-extractor + /trace-optimize --dry-run (analysis only)
**Phase 2**: Integration with prompt-optimizer (full loop)
**Phase 3**: Combined trigger with auto-trigger.md (proactive suggestions)

## Files Created/Modified

| File | Action | Purpose |
|------|--------|---------|
| `scripts/trace-pattern-extractor.sh` | Create | Trace analysis engine |
| `.claude/commands/trace-optimize.md` | Create | New slash command |
| `.claude/skills/prompt-optimizer/SKILL.md` | Modify | Add --from-traces mode |
| `.claude/skills/prompt-optimizer/auto-trigger.md` | Modify | Add trace signals |

## References

- `agent-trace-log.sh` — existing trace collection hook
- `prompt-optimizer/SKILL.md` — existing optimization skill
- `agent-observability-patterns.md` — observability architecture
- `agent-context-budget.md` — budget metering protocol
- Microsoft agent-lightning — closed-loop trace feedback pattern
