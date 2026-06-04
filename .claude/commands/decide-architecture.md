---
name: /decide-architecture
description: "Clasifica una tarea como WORKFLOW (deterministica) o AGENT (loop). Bias hacia workflow per Anthropic. Sugiere plantilla inicial. Mide accuracy contra corpus curado de 20 tareas."
developer_type: all
agent: task
context_cost: low
---

# /decide-architecture — Workflow vs Agent decision gate

> SPEC-158 — bias workflow-first per Anthropic effective-agents thesis.

## Intent

Cuando recibes una tarea nueva y no sabes si va por SDD workflow (deterministico, predecible, paralelizable) o agente autonomo (loop con tools, exploracion), invoca este comando antes de empezar. Te devuelve clasificacion + razones + plantilla sugerida.

## Sintaxis

```bash
/decide-architecture "task description here"
/decide-architecture --json "task ..."
```

## Salida (texto)

```
DECISION: WORKFLOW|AGENT
workflow_score: N
agent_score: N
template: <ruta plantilla>
reasons:
  - <senal detectada con peso>
  - ...
```

## Salida (JSON)

```json
{
  "decision": "WORKFLOW",
  "workflow_score": 7,
  "agent_score": 0,
  "template": "docs/propuestas/_template-spec.md",
  "reasons": ["workflow:strong match 'deterministic' (+5)", ...]
}
```

## Heuristica

| Senal | Peso | Tipo |
|---|---|---|
| Verbos workflow: generate, compute, extract, format, parse... | +1 | WORKFLOW |
| Patrones workflow: deterministic, step 1, each file, for every... | +5 | WORKFLOW |
| Verbos agent debiles: understand, analyze, review, benchmark | +1 | AGENT |
| Verbos agent medios: explore, investigate, research, debug, decide... | +2 | AGENT |
| Patrones agent fuertes: loop until, iterate until, figure out, find the best... | +5 | AGENT |

**Bias**: WORKFLOW empieza con +1 base. En empate gana WORKFLOW (Anthropic: "workflow first, agent only when necessary").

## Plantillas sugeridas

- `WORKFLOW` -> `docs/propuestas/_template-spec.md` (escribir SPEC SDD ejecutable)
- `AGENT` -> `.claude/agents/_template.md` (definir agente con tools y loop)

## Ejecucion

```bash
bash scripts/decide-architecture.sh "$@"
```

## Validacion (AC)

`scripts/decide-architecture-corpus-test.sh` ejecuta 20 tareas curadas (10 workflow, 10 agent). AC: accuracy >=85%. Estado actual: 20/20 = 100%.

## Cuando NO usar

- La tarea ya tiene SPEC aprobada (entonces es claramente workflow).
- El usuario indica explicitamente "delega a agent X" (skip clasificacion).
- Tarea trivial (<5 minutos) — overhead innecesario.
