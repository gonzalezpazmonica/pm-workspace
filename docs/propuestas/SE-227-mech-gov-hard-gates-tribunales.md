---
id: SE-227
title: Mech-gov hard gates pre-LLM + E3 entropy para tribunales Savia
status: PROPOSED
priority: P2
effort: M (6h)
origin: Research 2026-06-24 — github.com/SantanderAI/mech-gov-framework
author: Savia
related: truth-tribunal-orchestrator, recommendation-tribunal-orchestrator, SPEC-192
proposed_at: "2026-06-24"
era: 235
---

# SE-227 — Mech-gov: hard gates pre-LLM + E3 entropy para tribunales

## Problema

Los tribunales de Savia son pipelines 100% LLM. Tres problemas:

1. Coste innecesario: preguntas trivialmente rechazables (formato incorrecto, datos faltantes) consumen tokens de jueces LLM cuando un gate determinístico las filtraría en O(1).
2. Pre-cooking invisible: el modelo puede llegar a los jueces con la decisión ya tomada (positivity bias). El patrón E3 entropy commit-reveal detecta esto.
3. I6Q gap: si los argumentos de los jueces no superan un umbral de calidad mínimo, el tribunal debería emitir ESCALATE obligando a mejorar la pregunta.

## Tesis

Añadir una capa mecánica antes de los jueces LLM:

```
Input → hard_gates → E3_entropy_commit → CEFL → I6Q → ambiguity_gate → E3_reveal + output
```

Si un gate mecánico activa, el LLM no se llama. Reducción de coste + detección de pre-cooking.

## Diseño

### Hard gates (bash, determinísticos)

```bash
# Para Truth Tribunal:
hard_gate_format_check()    # el informe tiene secciones obligatorias
hard_gate_source_present()  # cada claim tiene @ref (source-traceability)
hard_gate_length_range()    # 500-10000 tokens

# Para Recommendation Tribunal:
hard_gate_no_empty_output()
hard_gate_spec_approved()
```

Si cualquier gate falla → devolver HARD_GATE_FAIL sin llamar a jueces.

### E3 nonce anti pre-cooking

1. El orchestrador genera nonce = sha256(input + timestamp_ms)
2. Los jueces reciben el input + nonce en el prompt
3. Los jueces incluyen el nonce en la primera línea del output
4. Si el nonce no aparece → flag E3_NONCE_MISMATCH en telemetría

### I6Q quality gate

Post-juicio: verificar densidad informativa de los argumentos (longitud mínima, evidencia concreta, ausencia de frases huecas). Si falla → ESCALATE: argumentos insuficientes.

## Slices

### Slice 1 — Hard gates Recommendation Tribunal (S, 2h)

- scripts/tribunal-hard-gates.sh: 5 gates determinísticos
- Integrar en recommendation-tribunal-orchestrator como step previo
- BATS: cada gate falla/pasa correctamente con inputs de referencia
- Medir reducción llamadas LLM en 10 casos de test

### Slice 2 — E3 nonce (M, 3h)

- Orchestrador genera nonce por invocación
- Cada juez incluye nonce en primera línea output
- Verificación post-juicio: E3_NONCE_MISMATCH en output/anti-adulation-telemetry.jsonl
- BATS: nonce presente PASS, ausente flag

### Slice 3 — Extender a Truth Tribunal + I6Q (M, 3h) [diferido]

- Hard gates para Truth Tribunal
- I6Q quality check post-juicio
- Baseline de coste antes/después

## Risks

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| Hard gates demasiado estrictos | Media | Modo warn antes de block; gates configurables |
| E3 nonce añade fricción | Baja | 1 línea en prompt de cada juez |
| I6Q umbrales subjetivos | Media | Calibrar con 50 casos reales |

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Hard gates | scripts/tribunal-hard-gates.sh | Bash puro |
| recommendation-tribunal-orchestrator | .opencode/agents/ | Lee desde AGENTS.md |
| truth-tribunal-orchestrator | .opencode/agents/ | Lee desde AGENTS.md |

### Portability classification

- [x] PURE_BASH: hard gates en bash stdlib. E3 nonce en Python stdlib.
