---
id: SE-224
title: Headroom effort routing + verbosity ladder para reducir output tokens
status: PROPOSED
priority: P2
effort: S (3h)
origin: Research 2026-06-24 — github.com/chopratejas/headroom
author: Savia
related: context-rot-strategy skill, context-caching skill, caveman-default.md (Rule #24)
proposed_at: "2026-06-24"
era: 235
---

# SE-224 — Headroom: effort routing + verbosity ladder

## Problema

Savia no gestiona los output tokens explícitamente. Cuando el último mensaje es un tool_result limpio (file read completo, test pass, bash output), el modelo genera la misma cantidad de razonamiento que ante una pregunta nueva. Resultado: ~29% output tokens desperdiciados en turns mecánicos.

Adicionalmente, el `caveman-default.md` implementa restricciones de verbosidad como regla de identidad, pero no como instrucción explícita en el request. La instrucción de verbosidad, si existe, se prepende al system prompt, invalidando el prefix cache del provider.

Cost of inaction: en sesiones largas (overnight-sprint, code-improvement-loop), los output tokens son el driver principal de coste. Cada turn mecánico innecesariamente verboso multiplica ese coste.

## Tesis

Implementar dos patrones extraídos de Headroom:

1. **Effort routing**: clasificar turns como `MECHANICAL` vs `NEW_ASK` y reducir effort en turns mecánicos.
2. **Verbosity steering en cola del system prompt**: instrucción de brevedad inyectada al final (no al inicio) para no invalidar prefix cache.

Ambos son implementables como hooks bash sin instalar headroom como dependencia.

## Diseño

### Effort routing (hook PreToolUse o equivalente)

Clasificación puramente estructural — cero LLM:

```
último message.role == "tool" y state.status == "completed" sin is_error → MECHANICAL → effort=low (o budget_tokens bajo)
cualquier message.role == "user" con texto → NEW_ASK → effort intacto
tool_result con is_error == true → ERROR → effort intacto
```

Implementación: hook `output-effort-router.sh` que inspecciona el último bloque del contexto y ajusta parámetros de la llamada.

### Verbosity ladder en cola system prompt

Niveles L0-L3:

```
L1: sin ceremony (ya en caveman-default.md)
L2 (default): L1 + no echo de contexto ya en ventana
L3: L2 + solo conclusiones (para tool_result masivos)
```

Instrucción inyectada como **append** al final del system prompt con sentinel tag `<!-- VERBOSITY_LEVEL:L2 -->` para idempotencia. La cabeza del system prompt (foundation, reglas críticas) queda intacta → prefix cache preservado.

### ContentRouter (compresión por tipo)

Para el skill `context-rot-strategy`: en vez de `/compact` genérico, detectar el tipo dominante del bloque a compactar:

- Tool output JSON masivo → dedup de arrays (SmartCrusher pattern)
- Código fuente → retener firmas, comprimir bodies
- Logs → retener ERRORs, comprimir INFOs repetidos
- Diffs → retener contexto del cambio

Implementado como función en el hook de compactación existente.

## Slices

### Slice 1 — Verbosity sentinel en cola system prompt (XS, 1h)

- Añadir al final de `caveman-default.md` o del hook de system prompt construction: sentinel tag + instrucción L2
- Verificar que prefix cache no se invalida (test: llamada con y sin sentinel, comparar cache_read_tokens)
- Criterio: cache_read_tokens no decrece vs baseline

### Slice 2 — Effort router hook (S, 2h)

- Hook `output-effort-router.sh` (PreToolUse o via plugin OpenCode)
- Clasificación: inspecciona último bloque del contexto
- Integrar en `.opencode/settings.json` como hook
- BATS: clasificación correcta de 10 casos (5 MECHANICAL, 5 NEW_ASK/ERROR)
- Medir reducción output tokens en sesión de referencia (baseline overnight-sprint)

### Slice 3 — ContentRouter en context-rot-strategy skill (S, 2h) [diferido]

- Extensión del skill `context-rot-strategy`: añadir tipo `/compact-typed`
- Detectar tipo dominante del contexto y aplicar compresor específico
- No requiere instalar headroom; lógica en Python stdlib

## Risks

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| effort=low degrada calidad en turns que parecen mecánicos | Media | Allowlist de herramientas siempre NEW_ASK (write, edit) |
| Sentinel invalida hooks existentes que leen system prompt | Baja | Sentinel al final, hooks leen desde inicio |
| ContentRouter comprime demasiado agresivo | Media | Ratio mínimo 50% preservación configurable |

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Verbosity sentinel | Hook PostToolUse appends sentinel | Plugin TS `onAfterToolCall` appends |
| Effort router | Hook PreToolUse ajusta params | Plugin TS `onBeforeModelCall` |

### Portability classification

- [x] **DUAL_BINDING**: hooks bash (Claude Code) + plugin TS (OpenCode).
