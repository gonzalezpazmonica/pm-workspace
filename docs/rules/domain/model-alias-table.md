# Model alias table — provider-agnostic resolution

> **Rule** — Agents and commands declare abstract capability tiers
> (`model: heavy|mid|fast`) in their frontmatter. The runtime maps those
> tiers to the provider-specific model ID via `~/.savia/preferences.yaml`.
> Hard-coded vendor model names in source files are a violation.
>
> **Updated 2026-05-03**: Savia runs on DeepSeek v4-pro via OpenCode.
> Agents and commands declare `model: heavy|mid|fast` — this table is
> informational; the runtime reads `~/.savia/preferences.yaml`.

## Resolution flow

```
agent/command frontmatter        ~/.savia/preferences.yaml
┌─────────────────────┐          ┌──────────────────────────┐
│ model: heavy         │──────────▶ model_heavy: deepseek-v4-pro
│ model: mid           │──────────▶ model_mid:   deepseek-v4-pro
│ model: fast          │──────────▶ model_fast:  deepseek-v4-flash
└─────────────────────┘          └──────────────────────────┘
```

## Current deployment (2026-05-03)

| Tier | `model:` value | Resolution | Tasks |
|---|---|---|---|
| Heavy | `heavy` | `deepseek-v4-pro` | Architecture, spec writing, security audit, code review |
| Mid | `mid` | `deepseek-v4-pro` | Feature implementation, refactoring, testing |
| Fast | `fast` | `deepseek-v4-pro` | Status queries, lookups, simple operations |

Cost: $0.435/1M input, $0.14/1M input (flash).

## Alternative stacks (examples, NOT presets)

### Anthropic API

```yaml
model_heavy: claude-opus-4-7
model_mid:   claude-sonnet-4-6
model_fast:  claude-haiku-4-5-20251001
```

### LocalAI via Ollama

```yaml
model_heavy: qwen3-72b-coder
model_mid:   qwen3-32b-coder
model_fast:  qwen3-7b
```

### GitHub Copilot Enterprise

```yaml
model_heavy: gpt-4o
model_mid:   gpt-4o-mini
model_fast:  gpt-3.5-turbo
```

## What this rule does NOT do

- It does not hardcode any vendor model name in source-controlled files.
- It does not auto-update — the user manages `~/.savia/preferences.yaml`.
- It does not validate model ids — the user knows their provider.
