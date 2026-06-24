---
id: SPEC-163
title: Router Modo 1 / Modo 2 (System 1/2 dispatch)
status: IMPLEMENTED
priority: HIGH
estimated_hours: 6
tier: 1A
origin: lecun-jepa-h-research-2026
implemented_at: "2026-06-24"
---

# SPEC-163 Router Modo 1 / Modo 2

## Problema
Hoy Savia ejecuta toda tarea con el mismo pipeline pesado: tribunal, jueces, validaciones. El 70% de las peticiones son triviales (consultas de estado, lookups, comandos directos) y consumen contexto desproporcionado. Sin gate de complejidad, cada `/status` paga el coste de un `/spec-write`.

LeCun distingue **Modo 1** (reactivo, rapido, sin simulacion) y **Modo 2** (deliberativo, con planificacion y critic). Savia hoy esta forzada a Modo 2 siempre.

## Solucion
Router pre-dispatch que clasifica cada turno como `mode_1` o `mode_2` antes de invocar agentes/skills/tribunal:

- **Modo 1**: respuesta directa del modelo principal, sin tribunal, sin reflection-validator, sin consensus. Tokens estimados < 5k.
- **Modo 2**: pipeline completo (tribunal, jueces, validacion). Tokens estimados >= 5k o complejidad declarada alta.

Clasificador inicial: heuristica + frontmatter del comando invocado (campo `complexity_tier: mode1 | mode2 | auto`). Auto usa LLM classifier ligero (haiku-tier).

## Slices
1. Schema `complexity_tier` en frontmatter de commands + classifier heuristico (2h)
2. Hook PreToolUse que rutea Task calls a pipeline reducido si mode_1 (2h)
3. Telemetria `output/router-decisions.jsonl` + tests BATS (2h)

## AC
- Comandos declaran `complexity_tier` en frontmatter
- Hook rutea correctamente >= 90% de casos en muestra de 50 turnos reales
- Modo 1 NO invoca recommendation-tribunal-orchestrator ni truth-tribunal
- Telemetria registra: turn_id, classified_mode, tokens_saved_estimate, agent_chain
- Tests BATS score >= 80

## Riesgos
- Clasificar erroneamente mode_2 como mode_1 → output sin validacion
- Mitigacion: SAVIA_ROUTER_MODE=shadow 2 semanas (clasifica pero ejecuta siempre mode_2), luego SAVIA_ROUTER_MODE=enforce

## Out of scope
- Clasificacion semantica profunda (deja para SPEC futura con embeddings)
- Fine-tuning del classifier
- Cambios al tribunal o jueces (solo cambia si se invocan)

## Origen
LeCun H-JEPA architecture: separacion explicita System 1 / System 2. Aplicado a Savia: el 70% de turnos no necesita deliberacion, solo respuesta directa.

## Trabajo relacionado (deferred LeCun improvements)
- configurator-explicit: hoy el "configurador" esta disperso entre identity + active-user + skills. Centralizarlo requiere refactor mayor (deferido).
- critic-RAG: anadir RAG sobre memoria al critic actual. Deferido a SPEC futura.
- actor-iterative pre-action: el actor itera POST-action (via tribunal). Iteracion PRE-action requiere world-model (ver SPEC-165).
