# Model alias table — provider-agnostic resolution (SPEC-127 Slice 1)

> **Rule** — Agents declare canonical Claude model names in their frontmatter.
> The runtime maps those names to the provider-specific model ID via this
> table. Hard-coded provider IDs in agent files are a violation.

## Why a runtime table, not a source patch

Savia ships 71 agents. 70 declare `model: claude-X-Y` in their frontmatter.
Patching all 70 to a provider-specific ID would:

- Lock agents to a single provider, breaking the trinity Claude/OpenCode/Copilot.
- Force a rewrite the next time the corporate plan changes models.
- Leak provider details into source-controlled artefacts (PV-03).

A runtime table resolves the alias at agent dispatch time. The table here is
the single source of truth — agents stay clean.

## Canonical alias mappings

| Canonical (agent declares) | Claude Code primary | Copilot Enterprise primary | Copilot fallback | LocalAI fallback |
|---|---|---|---|---|
| `claude-opus-4-7` | `claude-opus-4-7` | `github-copilot/claude-opus-4.7` | `github-copilot/o1` | `localai/qwen3-72b-coder` |
| `claude-sonnet-4-6` | `claude-sonnet-4-6` | `github-copilot/claude-opus-4.7` | `github-copilot/gpt-5.5` | `localai/qwen3-32b-coder` |
| `claude-haiku-4-5-20251001` | `claude-haiku-4-5-20251001` | `github-copilot/gpt-5.5-mini` | `github-copilot/o1-mini` | `localai/qwen3-7b` |

### Why these mappings

- **Opus → Copilot Opus**: same model family, max capability. No degradation.
- **Sonnet → Copilot Opus (primary)**: Copilot Enterprise plan typically
  exposes Opus but not Sonnet. Promoting Sonnet calls to Opus avoids a
  capability cliff. **Cost caveat**: Opus consumes ~5x premium reqs vs
  Sonnet under issue #8030. Slice 5 (quota guard) gates this.
- **Haiku → GPT-5.5-mini**: Haiku has no direct Copilot equivalent in the
  current corporate plan. GPT-5.5-mini matches latency/cost profile better
  than o1-mini for routine completion tasks.
- **Fallback to o1/gpt-5.5**: secondary Copilot models when primary is
  rate-limited or unavailable. Quality varies — log the fallback per call.
- **LocalAI fallback (SPEC-122)**: emergency mode. Quality drop is real and
  documented in `docs/rules/domain/emergency-mode-protocol.md`.

## Resolution function (provider-agnostic)

The resolver lives next to `savia-env.sh`. Pseudocode:

```
resolve_model(canonical, provider) → effective_id
  if provider == "claude":   return canonical
  if provider == "copilot":  return COPILOT_PRIMARY[canonical]  or  COPILOT_FALLBACK[canonical]
  if provider == "localai":  return LOCALAI_FALLBACK[canonical]
  return canonical  # unknown — caller handles
```

Provider override (`SAVIA_MODEL_OVERRIDE=...`) bypasses the table. Use only
for one-off experiments — never bake into agent frontmatter.

## Pending operator confirmation

The Copilot Enterprise rows in this table are based on the **default GitHub
Copilot Business + Enterprise model offering as of 2026-04**. They MUST be
verified against the actual corporate plan before Slice 2 ramps. Open
questions:

- Does the corporate plan include `claude-opus-4.7` under Copilot, or only
  `o1` and `gpt-5.5`? If only the latter, Sonnet-canonical agents downgrade
  to GPT-5.5 — adjust mapping.
- Is `gpt-5.5-mini` enabled, or only the full `gpt-5.5`? Affects Haiku row.
- Is there a token allowance per request, or per session?

These answers gate Slice 1 → Slice 2 transition. Until confirmed, the table
is **provisional**.

## What this rule does NOT do

- It does not provide a model-quality benchmark — pick a fallback by intuition,
  measure later.
- It does not prevent provider-specific agent behaviour — that is Slice 4
  (subagent fallback) and Slice 2 (hook portability).
- It does not auto-update — operator updates this table when the plan changes.

## References

- SPEC-127 Slice 1 AC-1.2: model-alias-table.md documents 3 mappings
  primary + fallback with reason.
- `docs/rules/domain/provider-agnostic-env.md`
- `scripts/savia-env.sh`
- SPEC-122 LocalAI emergency mode (`docs/rules/domain/emergency-mode-protocol.md`)
