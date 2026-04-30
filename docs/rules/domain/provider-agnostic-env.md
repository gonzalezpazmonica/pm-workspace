# Provider-agnostic environment layer (SPEC-127 Slice 1)

> **Rule** — Hooks, scripts and skills MUST resolve workspace path and provider
> via `scripts/savia-env.sh`, never by hard-coding `CLAUDE_PROJECT_DIR`.
> Source this rule when adding or refactoring a hook that reads env state.

## Why

Savia operates across four frontends:

| Frontend | Workspace env var | Hook surface | Slash commands |
|---|---|---|---|
| Claude Code (native) | `CLAUDE_PROJECT_DIR` | Full (PreToolUse, PostToolUse, Stop, ...) | Native |
| OpenCode-Claude | `OPENCODE_PROJECT_DIR` | Plugin TS (~25 events) | Partial (`.opencode/commands/`) |
| OpenCode-Copilot Enterprise | `OPENCODE_PROJECT_DIR` | **Zero** (no tool-call telemetry) | **Zero** (no slash mechanism) |
| LocalAI emergency (SPEC-122) | `CLAUDE_PROJECT_DIR` | Full (Claude Code shell) | Native |

Hard-coding `CLAUDE_PROJECT_DIR` breaks silently under OpenCode — the variable
is empty, `mkdir -p ""` is a no-op, telemetry writes to `/$USER.jsonl`, and the
hook reports success. Tests that read `CLAUDE_PROJECT_DIR` directly pass against
the file tree but mask the runtime regression.

## The contract

`scripts/savia-env.sh` is the single source of truth for two values:

- `SAVIA_WORKSPACE_DIR` — absolute path to the workspace root.
- `SAVIA_PROVIDER` — one of `claude | copilot | localai | <opencode-provider> | unknown`.

It also exposes capability probes that callers MUST respect when degrading
gracefully under reduced-surface providers:

- `savia_has_hooks` — returns 0 if hook events are available at runtime.
- `savia_has_slash_commands` — returns 0 if `/command-name` invocation is supported.

## Fallback chain (workspace dir)

```
SAVIA_WORKSPACE_DIR        # explicit override (any provider)
  → CLAUDE_PROJECT_DIR     # Claude Code native
  → OPENCODE_PROJECT_DIR   # OpenCode v1.14+
  → git rev-parse --show-toplevel
  → pwd                    # last resort
```

First non-empty value wins. The chain is order-stable — operators can override
with `SAVIA_WORKSPACE_DIR=/path` from any wrapper without disturbing the rest.

## Provider detection precedence

```
SAVIA_PROVIDER (operator override)
  → ANTHROPIC_BASE_URL points to localhost/localai → "localai"
  → COPILOT_TOKEN or GITHUB_COPILOT_TOKEN present → "copilot"
  → OPENCODE_PROVIDER set                          → "<value>"
  → CLAUDE_PROJECT_DIR present                     → "claude"
  → "unknown"
```

`unknown` callers MUST default to permissive behaviour for safety probes
(assume hooks present, slash commands present) and let downstream gates catch
the gap. Better a noisy hook than a silently-skipped credential check.

## How to use (hook author checklist)

1. Source `savia-env.sh` early — before any path-dependent operation:
   ```bash
   source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
   ```
2. Use `$SAVIA_WORKSPACE_DIR` instead of `$CLAUDE_PROJECT_DIR`.
3. Branch on capability probes when degrading:
   ```bash
   if ! savia_has_hooks; then
     # Reroute to git pre-commit or CI-only check (SPEC-127 Slice 2 TIER-2/3)
     exit 0
   fi
   ```
4. Never assume a specific provider — always probe.

## How to use (script author checklist)

- Replace direct `mkdir -p "$CLAUDE_PROJECT_DIR/output"` with
  `source scripts/savia-env.sh; mkdir -p "$SAVIA_WORKSPACE_DIR/output"`.
- For one-shot resolution from non-bash callers:
  `WORKSPACE=$(bash scripts/savia-env.sh workspace)`.
- For provider-conditional logic:
  `if [[ "$(bash scripts/savia-env.sh provider)" == "copilot" ]]; then ...`.

## Backward compatibility (PV-01)

Existing hooks that hard-code `CLAUDE_PROJECT_DIR` continue to work under
Claude Code — the loader exports `SAVIA_WORKSPACE_DIR` from the same value.
Migration is opt-in per-hook. Slice 2 of SPEC-127 patches the top 10 hooks by
execution weight; the remaining 54 follow on as touched.

## What this rule does NOT do

- It does not patch the 70+ existing hooks. Migration is incremental.
- It does not detect provider model — only frontend. Model alias mapping lives
  in `docs/rules/domain/model-alias-table.md`.
- It does not bypass autonomous-safety gates — provider override is operator-only.

## References

- SPEC-127 Slice 1 AC-1.1: hooks using `CLAUDE_PROJECT_DIR` can source
  `savia-env.sh` and obtain `SAVIA_WORKSPACE_DIR` with functional fallback
  under OpenCode shell.
- `docs/rules/domain/autonomous-safety.md`
- `scripts/savia-env.sh`
