---
id: SPEC-059
title: SPEC-059: Semantic Fault Handlers for Agent Recovery
status: PROPOSED
origin_date: "2026-03-30"
migrated_at: "2026-04-19"
migrated_from: body-prose
priority: media
---

# SPEC-059: Semantic Fault Handlers for Agent Recovery

> Status: **DRAFT** | Fecha: 2026-03-30
> Origen: AgentScope (agentscope-ai/agentscope) — parse_func + fault_handler
> Impacto: Structured error correction reduces retry waste and model escalation

---

## Problem

When a Savia agent fails, the recovery strategy is blunt:

1. Retry with same model (attempt 1)
2. Escalate to mid-tier model (attempt 2)
3. Escalate to top-tier model (attempt 3)
4. Give up, escalate to human (attempt 4+)

This is defined in `verification-before-done.md` and works for transient
failures (network, timeout). But it wastes tokens on **semantic failures**
where the agent produced output that is structurally wrong:

- Agent returns prose instead of the expected JSON/YAML format
- Agent includes files outside the allowed scope
- Agent modifies a file it should only read
- Agent output fails a validation check (tests, lint, schema)

In these cases, retrying with a bigger model is wasteful. The agent needs
**specific feedback about what went wrong** and **a correction strategy**
tailored to the error type.

## Inspiration

AgentScope separates error handling into two composable functions:

- `parse_func`: Validates and parses agent output. If parsing fails, the
  error message is fed back to the agent as a correction prompt.
- `fault_handler`: Catches exceptions during agent execution and applies
  recovery strategies (retry, fallback, skip, escalate).

This separation means format errors get cheap correction prompts (same model),
while infrastructure errors get retries or escalation.

## Proposed Design

### Error Taxonomy

| Category | Examples | Recovery Strategy |
|----------|----------|-------------------|
| FORMAT | Wrong output structure, missing fields | Correction prompt (same model) |
| SCOPE | Files outside spec, unauthorized actions | Correction prompt + scope reminder |
| VALIDATION | Tests fail, lint errors, schema mismatch | Correction prompt + error output |
| TRANSIENT | Timeout, network, rate limit | Retry (same model, with backoff) |
| CAPACITY | Context exhaustion, token budget exceeded | Model escalation |
| LOGIC | Incorrect implementation, wrong algorithm | Model escalation + expanded context |

### Fault Handler Chain

```
Agent produces output
  │
  ├─ parse_func(output) → OK? → Continue pipeline
  │
  ├─ parse_func fails → classify error category
  │   │
  │   ├─ FORMAT/SCOPE/VALIDATION → correction_prompt(error_detail)
  │   │   └─ Re-invoke SAME agent, SAME model, with error feedback
  │   │       └─ Max 2 correction attempts before escalating
  │   │
  │   ├─ TRANSIENT → retry with backoff (existing behavior)
  │   │
  │   └─ CAPACITY/LOGIC → model escalation (existing behavior)
  │
  └─ fault_handler catches exception → log + classify + route
```

### Correction Prompt Template

When parse_func detects a FORMAT/SCOPE/VALIDATION error:

```
Your previous output had an issue:
Category: {FORMAT|SCOPE|VALIDATION}
Detail: {specific error message}
Expected: {what was expected}
Actual: {what was received}

Fix the issue and produce corrected output. Do not repeat the full
implementation — only fix the specific problem identified above.
```

### Integration Points

1. **dev-session protocol**: Phase 3 (implement) and Phase 4 (validate)
   use parse_func to check developer output before passing to tester.
2. **commit-guardian**: CHECK 3-6 (build, tests, format, code review)
   produce structured errors that map to VALIDATION category.
3. **consensus-validation**: Judge outputs validated by parse_func for
   expected verdict format (VALIDATED/CORRECTED/REQUIRES_RETHINKING).
4. **handoff-templates**: Invalid handoffs (missing fields) trigger
   FORMAT correction instead of full retry.

### Configuration per Agent

Agents can declare their fault handler preferences in frontmatter:

```yaml
fault_handling:
  max_corrections: 2       # Max FORMAT/SCOPE/VALIDATION retries
  max_retries: 1           # Max TRANSIENT retries
  escalation_threshold: 3  # Total failures before model escalation
  parse_func: "json"       # Expected output format (json|yaml|markdown|free)
```

Default if not specified: max_corrections=2, max_retries=1, escalation=3.

## Token Economics

| Scenario | Current cost | With fault handlers |
|----------|-------------|-------------------|
| Format error (wrong JSON) | Full retry with bigger model (~8K tokens) | Correction prompt (~500 tokens) |
| Scope violation | Full retry (~8K tokens) | Correction prompt (~300 tokens) |
| Test failure | Full retry (~8K tokens) | Correction with error output (~1K tokens) |
| Network timeout | Retry (same) | Retry (same) — no change |

Estimated savings: 60-80% token reduction on semantic failures.

## What Does NOT Change

- Model escalation policy for CAPACITY/LOGIC errors (unchanged)
- Human escalation after max attempts (unchanged)
- Agent frontmatter format (new fields are optional, backward compatible)
- AGENT_MAX_CONSECUTIVE_FAILURES (3) from pm-config (still applies)

## Implementation Plan

1. Define error taxonomy in `docs/rules/domain/agent-fault-taxonomy.md`
2. Update `handoff-templates.md` with correction prompt template
3. Update `verification-before-done.md` to reference fault taxonomy
4. Update agent frontmatter docs to include `fault_handling` section
5. No script changes in Phase 1 — orchestrators apply the pattern manually

## Success Criteria

- FORMAT errors resolved in 1 correction attempt (no model escalation) >80%
- Total token spend on agent retries drops 40%+ (measured via agent-trace)
- Zero increase in human escalations (corrections catch what retries missed)
