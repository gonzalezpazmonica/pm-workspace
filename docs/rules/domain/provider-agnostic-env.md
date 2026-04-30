# Provider-agnostic environment layer (SPEC-127 Slice 1)

> **Rule** — Hooks, scripts and skills MUST resolve workspace path, provider
> name, and capability availability via `scripts/savia-env.sh`, never by
> hard-coding `CLAUDE_PROJECT_DIR` or branching on a vendor name.
> Source-controlled files NEVER reference a specific vendor (PV-06).

## Why

Savia operates across an open set of frontends and inference providers. Every
combination is the user's choice — Claude Code with Anthropic API, OpenCode
with LocalAI, Codex with a custom corporate endpoint, Cursor with Ollama,
some future frontend with some future provider. The framework must not assume
any specific stack.

Hard-coding `CLAUDE_PROJECT_DIR` breaks silently when the frontend is not
Claude Code — variable empty, `mkdir -p ""` no-op, telemetry writes to
`/$USER.jsonl`, hook reports success. Tests pass against the file tree but
mask the real-world regression.

Hard-coding a vendor branch (`if [[ "$provider" == "vendor-x" ]]`) creates
lock-in: a user with a different stack is a second-class citizen. Extending
to new vendors requires patching every hook.

## The contract

`scripts/savia-env.sh` is the single source of truth for four values:

- `SAVIA_WORKSPACE_DIR` — absolute path to the workspace root.
- `SAVIA_PROVIDER` — free-form provider name (whatever the user declared in
  preferences, or autodetected from env vars). Callers MUST NOT branch on
  hardcoded vendor names.
- Capability probes:
  - `savia_has_hooks` — returns 0 if hook events are available at runtime.
  - `savia_has_slash_commands` — returns 0 if `/command-name` invocation is supported.
  - `savia_has_task_fan_out` — returns 0 if subagent delegation is supported.

Probes are the **only correct way** to branch on capability. Vendor name is
informational (logs, telemetry).

## Fallback chain (workspace dir)

```
SAVIA_WORKSPACE_DIR        # explicit override (any provider)
  → CLAUDE_PROJECT_DIR     # Claude Code native
  → OPENCODE_PROJECT_DIR   # OpenCode v1.14+
  → git rev-parse --show-toplevel
  → pwd                    # last resort
```

First non-empty value wins. The chain is order-stable.

## Provider detection precedence

```
SAVIA_PROVIDER (env override, operator one-shot)
  → ~/.savia/preferences.yaml `provider:` (user declared)
  → autodetect from env vars (ANTHROPIC_BASE_URL → "local" if pointing at
    localhost; CLAUDE_PROJECT_DIR → "claude-code"; OPENCODE_PROJECT_DIR →
    "opencode"; else "unknown")
```

`unknown` is permissive by default for safety probes (assume capabilities
present, let downstream gates catch the gap). Better a noisy hook than a
silently-skipped credential check.

## How to use (hook author checklist)

1. Source `savia-env.sh` early — before any path-dependent operation:
   ```bash
   source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
   ```
2. Use `$SAVIA_WORKSPACE_DIR` instead of `$CLAUDE_PROJECT_DIR`.
3. Branch on capability probes when degrading:
   ```bash
   if ! savia_has_hooks; then
     # Reroute to git pre-commit (TIER-2) or CI-only (TIER-3)
     exit 0
   fi
   ```
4. Never branch on `$SAVIA_PROVIDER` to gate vendor-specific behaviour.
   That is vendor lock-in (PV-06). Use capability probes.

## How to use (script author checklist)

- Replace direct `mkdir -p "$CLAUDE_PROJECT_DIR/output"` with
  `source scripts/savia-env.sh; mkdir -p "$SAVIA_WORKSPACE_DIR/output"`.
- For one-shot resolution from non-bash callers:
  `WORKSPACE=$(bash scripts/savia-env.sh workspace)`.

## User preferences file

`~/.savia/preferences.yaml` is the per-user source of truth for stack
declaration. Created and managed by `scripts/savia-preferences.sh`. Never
committed to the repo. Schema documented in `model-alias-schema.md`.

Forbidden in preferences.yaml: `api_key`, `password`, `secret`, `token` keys.
Use a credential manager (env vars, OS keychain, vault). The validator
rejects these keys.

## Backward compatibility (PV-01)

Existing hooks that hard-code `CLAUDE_PROJECT_DIR` continue to work under
Claude Code — the loader exports `SAVIA_WORKSPACE_DIR` from the same value.
Migration is opt-in per-hook. Slice 2 of SPEC-127 patches the top 10 hooks
by execution weight; the remaining 54 follow on as touched.

## What this rule does NOT do

- It does not patch the 70+ existing hooks. Migration is incremental.
- It does not encode any vendor in source — model alias mappings live in
  `~/.savia/preferences.yaml` per-user.
- It does not bypass autonomous-safety gates — provider override is operator-only.

## References

- SPEC-127 Slice 1 AC-1.1, AC-1.4
- `docs/rules/domain/autonomous-safety.md`
- `docs/rules/domain/model-alias-schema.md`
- `scripts/savia-env.sh`
- `scripts/savia-preferences.sh`
