---
context_tier: L2
token_budget: 500
---

# Agent Idle Detection Protocol — SE-206

> When to use `agent-wait-idle.sh` instead of fixed `sleep`.

## Problem

`overnight-sprint` and `code-improvement-loop` used fixed `sleep`/timeout
to wait between injected tasks. This wastes time when the agent finishes
early, and causes race conditions when the agent is still busy.

## Solution

`scripts/agent-wait-idle.sh` polls process activity and exits as soon as
the agent has been silent for `--idle-threshold` seconds.

## When to use

- Before injecting the next task in `overnight-sprint`
- Before sending a follow-up prompt in `code-improvement-loop`
- Any automated pipeline that drives an AI agent process

## Usage pattern (overnight-sprint integration)

```bash
# Launch agent task in background, capture PID and log
claude --task "$TASK" --log /tmp/agent-$TASK_ID.log &
AGENT_PID=$!

# Wait for idle instead of fixed sleep
bash scripts/agent-wait-idle.sh \
  --pid "$AGENT_PID" \
  --log "/tmp/agent-$TASK_ID.log" \
  --timeout "$((AGENT_TASK_TIMEOUT_MINUTES * 60))" \
  --idle-threshold 5 \
  --json

EXIT=$?
case $EXIT in
  0) echo "Agent idle — injecting next task" ;;
  1) echo "Timeout — registering as timeout in results.tsv" ;;
  2) echo "Agent process ended — check exit code" ;;
esac
```

## Known prompt patterns (idle heuristics)

| Agent / Shell      | Idle indicator            |
|--------------------|---------------------------|
| Claude Code        | `> ` or `❯ ` at line start |
| OpenCode           | Blank line after assistant turn |
| Generic bash       | Shell prompt `$ ` or `# ` |
| tmux pane idle     | Cursor at column 0 after newline |

These patterns are informational — the script uses I/O silence (mtime / fdinfo),
not prompt pattern matching, which is more reliable.

## Exit codes

| Code | Meaning                      | Recommended action           |
|------|------------------------------|------------------------------|
| 0    | Idle detected                | Inject next task             |
| 1    | Timeout                      | Record as `timeout` in TSV   |
| 2    | Process dead                 | Read exit code; may be done  |
| 3    | Bad arguments                | Fix calling script            |

## Flags reference

| Flag                  | Default | Description                              |
|-----------------------|---------|------------------------------------------|
| `--pid <N>`           | —       | PID to monitor (required)               |
| `--timeout <sec>`     | 300     | Hard cap; emit `timeout` on expiry      |
| `--poll-interval <s>` | 2       | Sampling frequency                      |
| `--idle-threshold <s>`| 5       | Silence duration needed to call idle    |
| `--log <file>`        | —       | Log file mtime tracking (mode A)        |
| `--json`              | false   | JSON output instead of plain text       |
| `--dry-run`           | false   | Print config; do not wait               |

## Source

SE-206 · Inspired by Orca `terminal wait --for tui-idle` (orca-savia-20260607.md §7.2).
