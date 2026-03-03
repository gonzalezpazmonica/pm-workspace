# Async Hooks Configuration

> Hooks that don't block the main flow run with `async: true`.

---

## Principle

Observability and logging hooks should NEVER block user interaction.
Mark them as `async: true` so they run in the background.

## Hook Classification

| Hook | Type | Async | Rationale |
|---|---|---|---|
| `session-init.sh` | Command | No | Must complete before session starts |
| `block-credential-leak.sh` | Command | No | Security gate — must block |
| `block-force-push.sh` | Command | No | Safety gate — must block |
| `validate-bash-global.sh` | Command | No | Safety gate — must block |
| `scope-guard.sh` | Command | No | Scope validation — must block |
| `tdd-gate.sh` | Command | No | Quality gate — must block |
| `prompt-hook-commit.sh` | Prompt | No | Commit validation — must block |
| `agent-hook-premerge.sh` | Agent | No | Pre-merge gate — must block |
| `agent-trace-log.sh` | Command | **Yes** | Logging only — never block |
| `context-tracker-hook.sh` | Command | **Yes** | Metrics only — never block |
| `plan-gate.sh` | Command | No | Plan approval — must block |
| `pre-commit-review.sh` | Command | No | Review gate — must block |

## Implementation

In `.claude/settings.json`, async hooks use:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Bash|Edit|Write",
      "command": ".claude/hooks/agent-trace-log.sh",
      "async": true
    }]
  }
}
```

## Auto-Compact Configuration

```
CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50
```

This triggers automatic context compaction at 50% usage (vs default ~80%).
Add to `.claude/settings.json` or environment variables.

## Hook Event Coverage

| Event | Hooks | Coverage |
|---|---|---|
| SessionStart | session-init.sh | 1/1 |
| PreToolUse | 5 hooks | 5/5 |
| PostToolUse | agent-trace-log.sh | 1/1 |
| Stop | prompt-hook-commit.sh | 1/1 |
| SubagentStop | agent-hook-premerge.sh | 1/1 |
| **Total** | **9 unique hooks** | **9/16 events (56%)** |

Target: 12/16 events (75%) by v1.0.
