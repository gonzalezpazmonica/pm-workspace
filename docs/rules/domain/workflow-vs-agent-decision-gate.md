---
context_tier: L2
token_budget: 456
---

# Workflow vs Agent Decision Gate

> Ref SPEC-158. Applied 2026-06-04.

## Idea

Cada tarea nueva tiene dos rutas: workflow deterministico (SDD spec) o agente autonomo (loop con tools). Anthropic insiste en workflow-first. Sin gate explicito hay sesgo a invocar agentes (mas potentes pero mas costosos en contexto y latencia).

## Comando

`/decide-architecture "<task description>"` invoca `scripts/decide-architecture.sh` que clasifica via heuristica de keywords con tres niveles de senal y devuelve decision + razones + plantilla sugerida.

## Heuristica

- WORKFLOW empieza con +1 (bias Anthropic).
- WORKFLOW weak (+1): generate, compute, extract, format, parse, transform, calculate, list, count, sort, render, build, deploy, run, query, fetch, update, insert, delete, read, write, append, rename, copy, move.
- WORKFLOW strong (+5): "deterministic", "step 1", "each file", "for every", "spec-driven", etc.
- AGENT weak (+1): understand, analyze, review, evaluate, benchmark.
- AGENT medium (+2): explore, investigate, research, debug, troubleshoot, triage, decide, choose, recommend, compare.
- AGENT strong (+5): "loop until", "iterate until", "figure out", "find the best", "discover which", "self-correct", "exploratory", etc.

## Tie-break

En empate gana WORKFLOW. La carga de la prueba esta en demostrar que se necesita un agente.

## Validacion

Corpus curado de 20 tareas (10 workflow, 10 agent). Accuracy actual 20/20 = 100%. AC: >=85%.

Re-ejecutar tras cambiar pesos: `bash scripts/decide-architecture-corpus-test.sh`.

## Plantillas

WORKFLOW genera referencia a `docs/propuestas/_template-spec.md`. AGENT genera referencia a `.claude/agents/_template.md`.

## Quien decide finalmente

Esta heuristica es advisory. Humano puede overrride. Casos ambiguos deben anotar razon en la spec o en el log del agente.
