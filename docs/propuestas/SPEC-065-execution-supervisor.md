# SPEC-065 — Execution Supervisor

## Problem

Savia attempted to push a PR through CI 6 times with the same class of error.
Each attempt patched the previous failure instead of stopping to analyze the
root cause pattern. This wasted time, tokens, and produced inconsistent patches.

The core issue: nothing forced a pause to ask "am I patching symptoms or
fixing the cause?" before retry attempt 3, 4, 5, 6.

## Solution: Two Interconnected Systems

### System 1: Session Action Log

Append-only JSONL at `output/session-action-log.jsonl` tracking every
significant action: commits, pushes, pr-plan runs, CI checks, agent launches.

Format per entry:
```json
{"ts":"ISO-8601","action":"git-push","target":"feat/X","result":"fail",
 "detail":"CI: 67 BATS failures","attempt":3,"session":"$$"}
```

The `attempt` counter increments for repeated actions on the same target
within the same session (identified by `$$` — shell PID).

Script: `scripts/session-action-log.sh` with 4 subcommands:
- `log <action> <target> <result> <detail>` — append entry
- `attempts <action> <target>` — return attempt count
- `history <action>` — last 10 entries of this action type
- `reset` — clear log for new session

### System 2: Execution Supervisor

Advisory checker called after every failed action. Reads attempt count
from the action log and displays a mandatory reflection prompt at attempt 3+.

Script: `scripts/execution-supervisor.sh`:
- Called with: `<action> <target> <detail>`
- Reads attempt count from session-action-log.sh
- Attempt 1-2: silent (exit 0)
- Attempt 3: display reflection prompt to stderr
- Attempt 4+: same prompt plus "consider redesigning approach"
- ALWAYS exits 0 — advisory, never blocking

### Reflection Prompt (attempt 3)

```
SUPERVISOR: 3rd failed attempt on [action] -> [target].

Previous attempts:
1. [detail from log]
2. [detail from log]
3. [detail from log]

STOP. Before attempting again:
1. What is the ROOT CAUSE pattern across all 3 failures?
2. Are you patching symptoms or fixing the cause?
3. What would a senior engineer do differently?

Write your analysis before proceeding.
```

## Implementation: Hook (Option A) — Recommended

### Why hooks over prompts or wrappers

| Option | Reliability | Maintenance | Coverage |
|--------|------------|-------------|----------|
| A: Hook | 100% deterministic | Low | All bash failures |
| B: Wrapper | 100% deterministic | Medium | Only wrapped scripts |
| C: Rule | ~80% (LLM forgets) | Low | Depends on context |

**Decision: Option A (hook) + Option B (targeted integration).**

Hook catches all failures deterministically. Targeted integration in
pr-plan.sh and push-pr.sh adds explicit logging of action details.

### Hook placement

PostToolUse on Bash. The hook checks exit code and, if non-zero,
calls execution-supervisor.sh. However, this would fire on EVERY
bash failure (including grep, test, etc.) which is too noisy.

**Revised decision: Option B (targeted integration) only.**

Integration points in pr-plan.sh and push-pr.sh call the supervisor
explicitly after failures. This is deterministic AND scoped to the
actions that matter. The scripts already have failure handling — we
add 2-3 lines to each.

## Integration Points

### pr-plan.sh (after gate failure, ~line 52)

```bash
bash scripts/session-action-log.sh log "pr-plan" "$BRANCH" "fail" "$STOPPED"
bash scripts/execution-supervisor.sh "pr-plan" "$BRANCH" "$STOPPED"
```

### push-pr.sh (after PR creation failure, ~line 84)

```bash
bash scripts/session-action-log.sh log "push-pr" "$BRANCH" "fail" "$PR_URL"
bash scripts/execution-supervisor.sh "push-pr" "$BRANCH" "$PR_URL"
```

## Constraints

- Both scripts under 80 lines each
- Supervisor is ADVISORY — exit 0 always
- Log is session-scoped (PID-based)
- No external dependencies beyond bash + jq-less JSON
- Integrates with existing feedback_root_cause_always.md lesson

## Files

| File | Lines | Purpose |
|------|-------|---------|
| `scripts/session-action-log.sh` | <=80 | Action log CRUD |
| `scripts/execution-supervisor.sh` | <=80 | Reflection trigger |
| `scripts/pr-plan.sh` | +3 lines | Integration |
| `scripts/push-pr.sh` | +3 lines | Integration |
| `tests/evals/test-execution-supervisor.bats` | <=150 | 10+ tests |

## Success Criteria

1. On 3rd failed push, Savia sees the reflection prompt
2. The prompt shows history of all 3 attempts
3. The log survives across commands within a session
4. Reset works for new sessions
5. Zero impact on successful operations
