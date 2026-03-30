# SPEC-057: Fanout Pipeline for Parallel Agent Broadcast

> Status: **DRAFT** | Fecha: 2026-03-30
> Origen: AgentScope (agentscope-ai/agentscope) — fanout_pipeline + MsgHub
> Impacto: Faster multi-perspective analysis by broadcasting to N agents at once

---

## Problem

Savia has two orchestration patterns:
1. **Sequential pipeline** (SDD): analyst -> architect -> spec-writer -> developer
2. **DAG scheduling** (dag-scheduling skill): dependency graph with parallel cohorts

Both require the orchestrator to know the execution order upfront. There is no
**broadcast** pattern where the same input goes to N independent agents and
their responses are collected and synthesized.

Current workarounds are ad-hoc: consensus-validation calls 3 judges sequentially
(reflection-validator, code-reviewer, business-analyst), waiting for each to
finish before starting the next. This wastes time when judges are independent.

## Inspiration

AgentScope provides `fanout_pipeline(agents, input, enable_gather=True)` which
sends the same input to all agents concurrently via `asyncio.gather()` and
collects responses. MsgHub extends this with dynamic participant management.

## Proposed Design

### Fanout Primitive

A new orchestration pattern available to any command or skill:

```yaml
fanout:
  input: AgentMessage    # Same message broadcast to all agents
  agents:                # List of agents to invoke in parallel
    - reflection-validator
    - code-reviewer
    - business-analyst
  timeout_seconds: 120   # Per-agent timeout
  collect: all           # "all" | "first" | "majority"
  on_timeout: partial    # "partial" (use what finished) | "abort"
```

### Collect Strategies

| Strategy | Behavior | Use case |
|----------|----------|----------|
| all | Wait for every agent, fail if any times out | Consensus validation |
| first | Return first response, cancel others | Quick opinion |
| majority | Wait for >50% responses | Resilient voting |

### Integration with Existing Patterns

1. **consensus-validation**: Replace sequential 3-judge invocation with
   fanout + all collect. Expected speedup: 3x (120s -> 40s).
2. **security-pipeline**: Broadcast code to security-attacker +
   security-defender + security-auditor simultaneously.
3. **dev-session Phase 4**: test-engineer + coherence-validator already
   documented as "parallel" but implemented sequentially. Fanout fixes this.
4. **PR review**: multi-perspective review (5 agents) becomes a single
   fanout call instead of 5 sequential Task invocations.

### Conflict Resolution

When multiple agents return contradictory results:
- Use existing consensus scoring (weighted average per consensus-protocol.md)
- Fanout only collects — it does not resolve. Resolution is the caller's job.
- Dissent detection from consensus-protocol.md applies unchanged.

## Implementation Plan

### Phase 1: Script wrapper
`scripts/fanout-agents.sh` that accepts agent list + input, invokes N
Task calls, collects results into `output/fanout/{timestamp}/` directory
with one file per agent response.

### Phase 2: Skill integration
Update `consensus-validation/SKILL.md` to use fanout pattern.
Update `adversarial-security` skill to use fanout for 3 security agents.

### Phase 3: DAG integration
Extend dag-scheduling skill to support fanout nodes (same input, no
dependencies between siblings) as a first-class node type.

## Constraints

- Max concurrent agents: `SDD_MAX_PARALLEL_AGENTS` (5, from pm-config)
- Each agent runs in isolation (no shared state between fanout siblings)
- Fanout respects agent context budgets (agent-context-budget.md)
- Timeout per agent, not per fanout (one slow agent does not kill all)

## What Does NOT Change

- Agent implementation (agents are unaware they are in a fanout)
- DAG scheduling for dependency-based flows (fanout is complementary)
- Consensus scoring logic (only the invocation pattern changes)

## Success Criteria

- consensus-validation completes in <50s (vs current ~120s sequential)
- security-pipeline runs 3 agents in parallel
- No increase in total token consumption (same agents, same prompts)
