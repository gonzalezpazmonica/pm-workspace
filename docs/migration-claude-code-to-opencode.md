# Migrating Savia from Claude Code to OpenCode

> **Audience**: any operator running Savia today on Claude Code who wants
> to switch to OpenCode v1.14+ as the frontend, keeping their inference
> provider of choice.
>
> **Reading time**: ~5 minutes. **Migration time**: ~10-15 minutes for the
> happy path. Rollback is one command.

## What you keep, what you give up

Under OpenCode v1.14, Savia preserves:

- **All 90 skills** loaded as workspace context (auto-discoverable via
  `SKILLS.md` cross-frontend mirror).
- **All 70 agents** invocable natively (via the converter
  `scripts/agents-opencode-convert.sh` that translates the schema).
- **All 534 slash commands** discoverable via `.opencode/commands/`
  symlink — your existing `/sprint-status`, `/savia-board` and the rest
  work as before.
- **Memory + personality + rules** loaded via 16 instructions in
  `opencode.json`: `MEMORY.md`, `savia.md`, `radical-honesty.md`,
  `autonomous-safety.md`, etc.
- **Top 5 safety hooks** ported to TypeScript (`block-credential-leak`,
  `block-gitignored-references`, `prompt-injection-guard`,
  `validate-bash-global`, `tdd-gate`) running as a single OpenCode plugin.

You give up (documented losses, not silent regressions):

- **`Task` subagent fan-out** when your provider doesn't expose it. Four
  orchestrators (court, truth-tribunal, recommendation-tribunal, dev)
  detect this and pivot to single-shot mode (Slice 4 IMPLEMENTED).
- **The other 59 hooks** stay as `.sh` files under Claude Code. Under
  OpenCode they run via git pre-commit (TIER-2) or CI (TIER-3) when
  applicable. Deuda explícita en `output/hook-portability-classification.md`.

## Step-by-step migration

### 1. Update OpenCode binary

```bash
opencode upgrade   # 1.14+ required for plugin SDK
opencode --version # verify ≥ 1.14.30
```

### 2. Configure your stack

```bash
bash scripts/savia-preferences.sh init
```

Eight neutral questions (frontend, provider, model_heavy/mid/fast,
capabilities, budget, auth). All answers are free-form — Savia does NOT
assume a vendor. Result is persisted to `~/.savia/preferences.yaml`,
**never committed to the repo**.

### 3. Convert the agents to OpenCode schema

```bash
bash scripts/agents-opencode-convert.sh --apply
```

Writes 70 converted agent files to `.opencode/agents/` (gitignored if
your workspace prefers; this repo commits them as the canonical mirror).
Re-run after editing `.claude/agents/*.md`.

### 4. Validate the bootstrap

```bash
bash scripts/opencode-migration-smoke.sh
```

Runs 6 checks: binary version, opencode.json valid, agents discovered,
commands discovered, skills index present, plugin foundation loads. Fails
loudly and tells you what to fix.

### 5. Verify with `opencode debug config`

```bash
opencode debug config | python3 -c '
import json, sys
d = json.load(sys.stdin)
print("agents:", len(d.get("agent",{})))
print("commands:", len(d.get("command",{})))
print("instructions:", len(d.get("instructions",[])))
'
```

Expected output (on the canonical workspace):
- `agents: 70`
- `commands: 547` (workspace + OpenCode defaults)
- `instructions: 16`

### 6. Smoke test a real session

```bash
opencode run "list 3 active commands"
```

If your `~/.savia/preferences.yaml` declares a working provider, this
returns a response that mentions Savia commands. Memory + personality +
rules are loaded automatically.

### 7. Optional — enable the budget guard

The advisory budget guard (`savia-budget-guard.sh`) is registered as
`PreToolUse "*"` in `.claude/settings.json`. Under OpenCode it runs via
the TS plugin foundation; under Claude Code it runs as the `.sh` hook.
**It never blocks** — it only warns at 70%/85%/95% of your monthly
budget. To disable, leave `budget_kind: none` in preferences.

## Rollback

If anything breaks:

```bash
unset SAVIA_PROVIDER         # forget any session override
opencode --version           # confirm OpenCode is installed but unused
```

Your Claude Code workflow is intact. The migration adds files; it does
NOT modify the existing `.claude/hooks/`, `.claude/agents/`, `.claude/commands/`
or `.claude/skills/`. PV-01 backward compat absoluto.

## Troubleshooting

- **"Configuration is invalid at .opencode/agents/X.md"** — re-run
  `agents-opencode-convert.sh --apply`. The bash hook on the source agent
  file may have been edited since the last conversion.
- **`opencode debug config` returns 0 agents** — `.opencode/agents/`
  symlink may be present (legacy). Remove it and re-run the converter.
- **"missing files" in instructions** — check that
  `.claude/external-memory/` symlink target exists (`~/.savia-memory`).
  OpenCode tolerates missing files; the smoke test reports them.
- **Plugin doesn't load** — `opencode debug config` should show the plugin
  registered. If not, `bun install` failed (run it manually inside
  `.opencode/`).

## References

- SPEC-127 — `docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md`
- `docs/rules/domain/provider-agnostic-env.md`
- `docs/rules/domain/model-alias-schema.md`
- `docs/rules/domain/subagent-fallback-mode.md`
