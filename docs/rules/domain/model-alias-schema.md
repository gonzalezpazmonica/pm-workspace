# Model alias schema — user-extensible mappings (SPEC-127 Slice 1)

> **Rule** — Agents and commands declare abstract capability tiers (`model: heavy|mid|fast`)
> in their frontmatter. The runtime maps those tiers to the user's provider-specific
> model id via `~/.savia/preferences.yaml`. Zero vendor names in source-controlled files.
> PV-06: cero vendor lock-in.

## Why a user-managed table

Savia ships 70+ agents and 500+ commands. Each declares a capability tier
(heavy / mid / fast), never a vendor model name. Every user's stack is
different: DeepSeek, Anthropic API, OSS hosted vendor, LocalAI on-prem,
Ollama local, enterprise vendor, custom corporate endpoint. Each user
declares **their** mappings in `~/.savia/preferences.yaml`. Agents and
commands stay clean; the repo stays neutral.

## Tier definitions

| Tier | `model:` value | Semantic | Example tasks |
|---|---|---|---|
| Heavy | `heavy` | Deep reasoning, architectural decisions | Spec writing, code review, security audit |
| Mid | `mid` | Balanced — implementation, testing | Feature development, refactoring, test writing |
| Fast | `fast` | Low-latency, low-cost | Status queries, simple lookups, quick checks |

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

Agents and commands declare `model: heavy|mid|fast` in their frontmatter.
The runtime resolves to the user's provider-specific model id:

```
resolve_model(tier) → effective_id
  preferences = read $HOME/.savia/preferences.yaml
  if tier == "heavy": return preferences.model_heavy
  if tier == "mid":   return preferences.model_mid
  if tier == "fast":  return preferences.model_fast
  else:               return tier  # passthrough (log warning)
```

No vendor names anywhere in the resolution path. The user controls
`~/.savia/preferences.yaml` — swap providers by changing three lines.

## Examples — illustrative, NOT presets

### A — DeepSeek via OpenCode

```yaml
version: 1
frontend: opencode
provider: deepseek
model_heavy: deepseek-v4-pro
model_mid:   deepseek-v4-pro
model_fast:  deepseek-v4-flash
has_hooks: yes
has_task_fan_out: yes
has_slash_commands: yes
budget_kind: none
auth_kind: api-key
```

### B — Anthropic API direct

```yaml
version: 1
frontend: claude-code
provider: anthropic
model_heavy: claude-opus-4-7
model_mid:   claude-sonnet-4-6
model_fast:  claude-haiku-4-5-20251001
has_hooks: yes
has_task_fan_out: yes
has_slash_commands: yes
budget_kind: token-count
auth_kind: api-key
```

### C — local OSS (LocalAI / Ollama)

```yaml
version: 1
frontend: opencode
provider: localai
model_heavy: qwen3-72b-coder
model_mid:   qwen3-32b-coder
model_fast:  qwen3-7b
has_hooks: yes
has_task_fan_out: no
has_slash_commands: yes
budget_kind: none
auth_kind: none
```

## What this schema does NOT do

- Does not name any vendor in agent/command source files.
- Does not validate model ids — the user knows their provider.
- Does not store credentials — use env vars / keychain / vault.

## References

- SPEC-127 Slice 1 AC-1.3
- `scripts/savia-preferences.sh`, `scripts/savia-env.sh`, `docs/rules/domain/provider-agnostic-env.md`
