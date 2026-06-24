---
globs: [".claude/hooks/**", ".opencode/plugin/**", "scripts/hook-multihandler-baseline.sh"]
context_tier: L2
token_budget: 1200
spec_ref: SPEC-150
status: in-progress
slice_current: 1
created: 2026-06-24
---

# Hook Multi-Handler Migration — Diseño

> Slice 1 completado: baseline FP/FN establecido.
> Ref: `docs/propuestas/SPEC-150-hooks-multi-handler-migration.md`

## Candidatos a migración (6 hooks evaluados en Slice 1)

| Hook | Tipo de problema | Evento OpenCode objetivo |
|---|---|---|
| `sycophancy-strip` | Semántico — regex pierde contexto | `chat.message` |
| `block-credential-leak` | Regex FP en docstrings | `tool.execute.before` |
| `contract-test-guard` | Path-matching — admite mejoras | `tool.execute.before` |
| `context-sanitize-input` | Bidi/homoglyph — buena cobertura | `tool.execute.before` |
| `pii-gate` | Regex FP en datos sintéticos | `tool.execute.before` |
| `router-mode-dispatch` | Clasificación — mejora con LLM | `tool.execute.before` |

## Criterio de migración

- `FP+FN rate >= 5%` → candidato a migración a plugin TS Layer 2
- `FP+FN rate < 5%` → mantener bash command (más barato, menor latencia)

Baseline: `scripts/hook-multihandler-baseline.sh` · Output: `tests/evals/hook-baselines/`

## Patrón de 2 capas

```
Layer 1 (bash regex — < 50ms, deterministic)
  └── .claude/hooks/{hook}.sh
  └── Fallback si Layer 2 falla

Layer 2 (TypeScript plugin — semántico, LLM judge)
  └── .opencode/plugin/{hook}-layer2.ts
  └── Haiku via client.completion.create()
  └── Timeout 1500ms → fallback Layer 1
```

## Anti-patterns

| Anti-pattern | Alternativa |
|---|---|
| `mcp_tool` para enforcement | Bash Layer 1 para enforcement; MCP solo para audit |
| Plugin sin fallback | Siempre mantener bash Layer 1 |
| LLM en cada PreToolUse | Matcher rápido → solo casos ambiguos a Layer 2 |
| `agent` handler en gates críticos | Opt-in únicamente, nunca enforcement |

## Plan por fases

- **Slice 1** (completado) — Baseline FP/FN, 20 inputs por hook
- **Slice 2** — Migrar hooks semánticos a plugin TS con fallback
- **Slice 3** — Audit trail via MCP (requiere SPEC-141)
- **Slice 4** — Session summary via fetch
- **Slice 5** — Agent handler opt-in
- **Slice 6** — Audit script + docs + cobertura completa

## Coste operativo

Límite spec: < $0.005/turno · < 800ms p95.
Recomendación: máximo 3 hooks con Layer 2 activo en producción.

## Relación con otros specs

- SPEC-141: MCP catalog (necesario para Slice 3)
- SPEC-151: Evals CI (plugins `prompt` necesitan eval continua)
- SPEC-142: Plugin tool.execute.before (primer caso del patrón)
- SPEC-192: Anti-adulation (`sycophancy-strip` candidato prioritario)
