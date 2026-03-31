---
globs: [".claude/settings.json", ".claude/hooks/**"]
---

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
| `bash-output-compress.sh` | Command | **Yes** | Output compression — never block |
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
CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=65
```

Triggers auto-compaction at 65% of effective window (~108K tokens for Opus 200K).
Set in `.claude/settings.json` env section. Previous value of 50% was too aggressive
(compacted after ~40K tokens). 65% balances session length with quality.
Note: effective window = contextWindow - 20K (output) - 13K (buffer) = ~167K.

## Environment Variables — Performance Tuning

```
BASH_MAX_OUTPUT_LENGTH=80000      # Max chars from Bash output (default 30K, upper 150K)
TASK_MAX_OUTPUT_LENGTH=80000      # Max chars from subagent output (default 32K, upper 160K)
ENABLE_TOOL_SEARCH=auto           # Deferred tool loading for 400+ tools
```

Set in `.claude/settings.json` env section. Raising output limits prevents
truncation before hooks can compress. Tool search reduces upfront context cost.

## Hook Event Coverage

| Event | Hooks | Coverage |
|---|---|---|
| SessionStart | session-init.sh | 1/1 |
| SessionEnd | session-end-memory.sh | 1/1 |
| PreToolUse | 12 hooks (6 matchers) | 12/12 |
| PostToolUse | 8 hooks (3 matchers) | 8/8 |
| PostToolUseFailure | post-tool-failure-log.sh | 1/1 |
| PreCompact | pre-compact-backup.sh | 1/1 |
| PostCompact | post-compaction.sh | 1/1 |
| Stop | 4 hooks | 4/4 |
| UserPromptSubmit | user-prompt-intercept.sh | 1/1 |
| **Total** | **31 hook instances** | **9/27 events (33%)** |

27 hook events available in Claude Code. Target: 15/27 (56%) by v1.0.
