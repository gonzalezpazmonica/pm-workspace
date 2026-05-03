# Model alias table — provider-agnostic resolution

> **Rule** — Agents declare canonical Claude model names in their frontmatter.
> The runtime maps those names to the provider-specific model ID via this
> table. Hard-coded provider IDs in agent files are a violation.
>
> **Updated 2026-05-03**: Added DeepSeek column. Savia now runs on DeepSeek
> v4-pro via OpenCode. Agents still declare `claude-sonnet-4-6` etc —
> this table resolves to `deepseek-v4-pro` at runtime.

## Why a runtime table, not a source patch

Savia ships 71 agents. 70 declare `model: claude-X-Y` in their frontmatter.
Patching all 70 to a provider-specific ID would:

- Lock agents to a single provider, breaking the trinity Claude/OpenCode/Copilot.
- Force a rewrite the next time the corporate plan changes models.
- Leak provider details into source-controlled artefacts (PV-03).

A runtime table resolves the alias at agent dispatch time. The table here is
the single source of truth — agents stay clean.

## Canonical alias mappings

| Canonical (agent declares) | OpenCode primary | DeepSeek (current) | Claude Code (legacy) | LocalAI fallback |
|---|---|---|---|---|---|
| `claude-opus-4-7` | `deepseek-v4-pro` | `deepseek-v4-pro` | `claude-opus-4-7` | `localai/qwen3-72b-coder` |
| `claude-sonnet-4-6` | `deepseek-v4-pro` | `deepseek-v4-pro` | `claude-sonnet-4-6` | `localai/qwen3-32b-coder` |
| `claude-haiku-4-5-20251001` | `deepseek-v4-flash` | `deepseek-v4-flash` | `claude-haiku-4-5-20251001` | `localai/qwen3-7b` |

### Why these mappings (2026-05-03)

- **All canonical → DeepSeek v4-pro**: Savia runs on OpenCode with DeepSeek
  v4-pro as primary backend. Opus, Sonnet, and Haiku all resolve to the
  same model. Cost: $0.435/1M input (75% off until 2026-05-31).
- **Haiku → v4-flash**: lightweight tasks use DeepSeek v4-flash.
  Cost: $0.14/1M input.
- **LocalAI fallback**: emergency mode when API unreachable. Qwen3 models
  via Ollama.
- **No Copilot**: Corporate Copilot not currently deployed for Savia.
  Original SPEC-127 Copilot rows removed. Add back if needed.

## Resolution function

```
resolve_model(canonical) → effective_id
  if provider == "deepseek": return "deepseek-v4-pro"     # current default
  if provider == "claude":   return canonical              # legacy fallback
  if provider == "localai":  return LOCALAI_FALLBACK[...]  # emergency
  return "deepseek-v4-pro"                                # default
```

Provider override (`SAVIA_MODEL_OVERRIDE=...`) bypasses the table.

## What this rule does NOT do

- It does not provide a model-quality benchmark.
- It does not auto-update — operator updates this table when the provider changes.
- It does not patch agent files. Agents stay with canonical names. Resolution is runtime.
