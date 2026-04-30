# Subagent fallback mode (single-shot expanded prompt) — SPEC-127 Slice 4

> **Rule** — Orchestrator agents that delegate work to subagents via the
> Task tool MUST detect `savia_has_task_fan_out` capability at runtime and
> pivot to single-shot mode when the user's stack does not support fan-out.
> Failure to pivot = silent regression: the orchestrator emits no output
> because Task is unavailable but never declared loss explicitly.

## Why

Four orchestrators in Savia depend on subagent fan-out:

- `court-orchestrator` (5 judges in parallel)
- `truth-tribunal-orchestrator` (7 judges)
- `recommendation-tribunal-orchestrator` (4 judges + classifier)
- `dev-orchestrator` (delegates plan slices to specialised agents)

When a user's stack does not expose subagent fan-out (`savia_has_task_fan_out`
returns false in `~/.savia/preferences.yaml` or via autodetect), these
orchestrators stop working: the Task tool returns an error, the orchestrator
either fails silently or emits a stub verdict. Downstream consumers (audit
trail, gate aggregators, CI pipelines) receive nothing or malformed data.

## The pattern: single-shot expanded prompt

Instead of delegating to a subagent in an isolated context, the orchestrator
**inlines** the target agent's system prompt into its own context, runs the
target's logic itself in the current LLM turn, and emits a wrapped result.

Trade-off: loses context isolation (orchestrator and target share working
memory), gains compatibility (works under any stack, no Task tool required).
Output schema preserved — downstream consumers are oblivious.

## Capability detection

```bash
mode=$(bash scripts/savia-orchestrator-helper.sh mode)
# returns "fan-out" or "single-shot"
```

Mode is derived from `~/.savia/preferences.yaml` `has_task_fan_out` key, with
autodetect fallback (Claude Code → yes; everything else → no).

## How to pivot (orchestrator pseudocode)

```
mode = bash scripts/savia-orchestrator-helper.sh mode

if mode == "fan-out":
  # Existing flow — Task tool delegates to N subagents in parallel
  for target in subagents:
    result = Task(subagent=target, prompt=...)
  aggregate(results)

else:  # single-shot
  results = []
  for target in subagents:
    target_prompt = bash scripts/savia-orchestrator-helper.sh inline-prompt <target>
    # Execute target's logic INLINED in this LLM turn
    # The orchestrator's own prompt now contains target's instructions
    # Run them, capture output
    raw = <run target logic with shared context>
    wrapped = bash scripts/savia-orchestrator-helper.sh wrap <target> <raw_file>
    results.append(wrapped)
  aggregate(results)
```

Both branches produce results with the same JSON shape:

```json
{"agent": "<name>", "mode": "fan-out|single-shot", "result": "..."}
```

Aggregators consume the same shape regardless of mode.

## Trade-offs (declare them, don't hide them)

Single-shot mode loses three things:

1. **Context isolation** — orchestrator and target share working memory.
   A target's intermediate reasoning leaks into the orchestrator's window.
   For 5+ judges this can blow context budget.
2. **Parallelism** — fan-out runs N subagents concurrently; single-shot
   runs them sequentially in one turn. Total tokens are similar, wall-clock
   time grows N×.
3. **Independent verdicts** — fan-out gives each judge a fresh context;
   single-shot judges share the orchestrator's context, so later judges may
   be biased by earlier ones if the orchestrator emits intermediate results.

To mitigate trade #3: orchestrator emits each target's result wrapped before
running the next target. The wrapper acts as a "context wall" — the
orchestrator references only the wrapped JSON, not target's intermediate
chain-of-thought.

## What this rule does NOT do

- It does not auto-pivot — orchestrator agents must implement the branch
  in their own prompt body.
- It does not handle nested delegation — if a single-shot target itself
  needs to delegate, the orchestrator must inline that level too.
- It does not preserve isolation — single-shot is a degradation, not a
  full equivalent. PV-05: the loss is documented, not hidden.

## Affected orchestrators (Slice 4 IMPLEMENTED)

| Orchestrator | Subagents under fan-out | Single-shot strategy |
|---|---|---|
| `court-orchestrator` | 5 judges | Sequential inline; each judge wrapped before next |
| `truth-tribunal-orchestrator` | 7 judges | Sequential inline + early stop on veto |
| `recommendation-tribunal-orchestrator` | 4 judges + classifier | Classifier first, judges sequential |
| `dev-orchestrator` | N implementation agents | Single-shot per slice |

Each orchestrator's `.md` file gains a "## Fallback mode" section instructing
the LLM agent how to detect and pivot. PV-01: existing fan-out flow unchanged.

## References

- SPEC-127 Slice 4 AC-4.1, AC-4.2, AC-4.3
- `scripts/savia-orchestrator-helper.sh`
- `scripts/savia-env.sh`
- `docs/rules/domain/provider-agnostic-env.md`
