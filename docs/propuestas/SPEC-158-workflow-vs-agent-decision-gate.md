---
id: SPEC-158
title: Workflow vs Agent Decision Gate
status: IMPLEMENTED
implemented_at: 2026-06-04
priority: HIGH
estimated_hours: 3
tier: 1C
origin: anthropic-effective-agents-thesis-2026
---

# SPEC-158 Workflow vs Agent Decision Gate

> Estado: IMPLEMENTED 2026-06-04. Heuristica 3-tier (weak/medium/strong),
> bias workflow +1, comando /decide-architecture, corpus 20 tareas
> accuracy 100%, BATS 31/31 audit 93/100.

## Problema
No hay criterio explicito para decidir si una tarea va por SDD workflow (deterministico) o agente autonomo (loop con tools). Anthropic insiste: workflow first, agente solo si es necesario. Sin gate, hay sesgo a invocar agentes (mas potentes pero mas costosos).

## Solucion
Comando /decide-architecture {task-description} que clasifica:
- WORKFLOW: pasos deterministicos, output predecible, dependencias claras
- AGENT: loop necesario, decisiones dinamicas, exploracion

Output: recomendacion + razones + plantilla inicial (spec SDD o invocacion Task).

## Slices
1. Heuristicas de clasificacion (1h)
2. Comando slash y plantillas (1h)
3. Tests y documentacion (1h)

## AC
- Clasifica 20 tareas reales con accuracy 85%+
- Genera plantilla apropiada segun resultado (spec.md vs Task invocation)
- Documenta razones de la decision en output del comando
- Peso explicito a workflow en heuristica (evita sesgo a agentes)

## Riesgos
Sesgo hacia agentes (mas potentes pero mas costosos). Mitigacion: peso explicito a workflow en heuristica + ejemplos curados.

## Out of scope
Migracion automatica de agentes existentes a workflows. Refactor de comandos actuales.
