# Model alias schema — user-extensible mappings (SPEC-127 Slice 1)

> **Rule** — Agents declare canonical Claude model names in their frontmatter.
> The runtime maps those names to the user's effective model id via
> `~/.savia/preferences.yaml`. The repo never contains a vendor-specific
> mapping table. PV-06: cero vendor lock-in en source-controlled files.

## Why a user-managed table

Savia ships 71 agents (70 declare `model: claude-X-Y`). Every user's stack is
different: Anthropic API direct, OSS hosted vendor, LocalAI on-prem, Ollama
local, enterprise vendor, custom corporate endpoint. A single hardcoded
mapping locks agents to one stack, forces rewrites on plan change, and leaks
vendor choice into source. Each user declares **their** mappings in
`~/.savia/preferences.yaml`. Agents stay clean; the repo stays neutral.

## Schema

`~/.savia/preferences.yaml` (top-level keys; managed by
`scripts/savia-preferences.sh`):

```yaml
version: 1                  # schema version (current: 1)

# Stack declaration — free-form strings. Framework branches on capabilities,
# not on vendor name.
frontend: <free-form>       # e.g. claude-code | opencode | codex | cursor | other
provider: <free-form>       # e.g. vendor name | "localai" | "ollama" | "custom-corp"

# Model aliases — three tiers. Each value is whatever model id your provider
# expects. Free-form. The framework never validates against a known list.
model_heavy: <free-form>    # heavy-tier model id (deep reasoning, slow)
model_mid:   <free-form>    # mid-tier model id (balanced)
model_fast:  <free-form>    # fast-tier model id (low-latency, low-cost)

# Capability declarations — yes / no / autodetect. autodetect uses env-var
# heuristics in scripts/savia-env.sh.
has_hooks:           <yes|no|autodetect>
has_task_fan_out:    <yes|no|autodetect>
has_slash_commands:  <yes|no|autodetect>

# Budget policy — Slice 5 reads this. "none" if the provider has no quota.
budget_kind:  <none|req-count|token-count|dollar-cap>
budget_limit: <integer-or-empty>

# Auth shape — informational. Credentials NEVER live here (use env vars / OS
# keychain / vault). The validator rejects api_key / password / secret /
# token keys outright.
auth_kind: <none|api-key|oauth|mtls|corporate-custom>
```

### Forbidden keys (rejected by validator)

- `api_key`
- `password`
- `secret`
- `token`

These belong in a credential manager, not a preferences file. The framework
will refuse to load preferences containing them.

## Resolution function (provider-agnostic)

When an agent declares `model: claude-sonnet-4-6`:

```
resolve_model(canonical) → effective_id
  preference = read $HOME/.savia/preferences.yaml model_<tier>
  if canonical maps to a tier (heavy / mid / fast):
    return preference[<tier>]
  else if user defined explicit override map:
    return user_map[canonical]
  else:
    return canonical  # let the frontend pass-through; if it fails, log & fail
```

Tier mapping convention (canonical → tier):
- `claude-opus-4-7`           → heavy
- `claude-sonnet-4-6`         → mid
- `claude-haiku-4-5-20251001` → fast

Users may override with explicit per-canonical mappings if their stack needs
different tier groupings; that extension lives in a future schema field
(`model_overrides:`) not implemented in Slice 1.

## Examples — illustrative, NOT presets

These examples show the **shape** of typical preferences for common stack
classes. NOT vendor recommendations — replace with your own.

### A — default Anthropic API (Claude Code native)

```yaml
version: 1
frontend: claude-code
provider: anthropic-api
model_heavy: claude-opus-4-7
model_mid:   claude-sonnet-4-6
model_fast:  claude-haiku-4-5-20251001
has_hooks: yes
has_task_fan_out: yes
has_slash_commands: yes
budget_kind: token-count
auth_kind: api-key
```

### B — local OSS (LocalAI / Ollama)

```yaml
version: 1
frontend: opencode
provider: localai
model_heavy: <large-model-you-pulled>
model_mid:   <mid-model-you-pulled>
model_fast:  <small-model-you-pulled>
has_hooks: yes
has_task_fan_out: no
has_slash_commands: yes
budget_kind: none
auth_kind: none
```

### C — vendor-managed with quota

```yaml
version: 1
frontend: opencode
provider: <vendor-name>
model_heavy: <vendor-heavy-model-id>
model_mid:   <vendor-mid-model-id>
model_fast:  <vendor-fast-model-id>
has_hooks: no
has_task_fan_out: no
has_slash_commands: no
budget_kind: req-count
budget_limit: 1500
auth_kind: oauth
```

## What this schema does NOT do

- Does not name a vendor in source — examples are placeholders.
- Does not validate model ids — the user knows their provider.
- Does not store credentials — use env vars / keychain / vault.

## References

- SPEC-127 Slice 1 AC-1.3
- `scripts/savia-preferences.sh`, `scripts/savia-env.sh`, `docs/rules/domain/provider-agnostic-env.md`
