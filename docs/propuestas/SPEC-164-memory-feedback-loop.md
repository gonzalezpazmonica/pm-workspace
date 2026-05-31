---
id: SPEC-164
title: Memory feedback loop (auto-memory writes from outcomes)
status: PROPOSED
priority: HIGH
estimated_hours: 5
tier: 1A
origin: lecun-jepa-h-research-2026
---

# SPEC-164 Memory Feedback Loop

## Problema
La memoria externa de Savia (`.claude/external-memory/auto/MEMORY.md`) es write-only desde scripts manuales (`memory-store.sh save`). No hay loop que escriba automaticamente cuando un agente termina con exito/fracaso, cuando un PR se merge, o cuando una decision arquitectonica se valida en produccion.

LeCun: sin feedback de outcome, la memoria no aprende. Es archivo, no aprendizaje.

## Solucion
Hooks PostToolUse y post-PR que escriben entradas estructuradas en memoria auto:

- **PostToolUse(Task)** → registra outcome del agente: success/failure, agent_name, duration, escalations, key_decisions extraidas del output
- **post-merge hook** → registra PR merged: spec_id, files_touched, judges_verdict, time_to_merge
- **post-spec-implemented** → registra spec completada: hours_actual vs estimated, viability_score, rework_count

Schema entrada: `{ts, source, outcome, agent_or_spec, signals: {...}, lesson: "<= 150 chars>"}`. Append a `MEMORY.md` con cap.

## Slices
1. Hook PostToolUse(Task) que extrae outcome + escribe entrada (2h)
2. Hook post-merge git (gh CLI o local) que registra PR outcome (1.5h)
3. Compactador periodico que consolida lessons recurrentes (1.5h)

## AC
- Cada Task call genera 1 entrada en MEMORY auto (success o failure)
- Cada PR merged en main genera 1 entrada con spec_id si detectable
- Compactador identifica lessons repetidas >= 3 veces y las promueve a `docs/rules/learned/`
- Cap 200 lineas / 25KB respetado (compactador cierra entradas viejas)
- Tests BATS score >= 80

## Riesgos
- Ruido en memoria si cada Task escribe → cap se llena rapido
- Mitigacion: filtro de entropia (solo escribe si outcome diverge de prediccion del propio agente)

## Out of scope
- Embeddings sobre memoria (deferido a SPEC futura, requiere infra vectorial)
- Memoria por usuario activo distinta (ya existe en active-user.md)
- Re-entrenamiento de modelos

## Origen
LeCun: la memoria asociativa solo es util si se actualiza con feedback del actor. Configurador y critic leen memoria; sin loop, leen historia muerta.

## Trabajo relacionado
- Depende de telemetria de SPEC-156 (token_budget projections) para detectar divergencias
- Sinergico con SPEC-163 (router): mode_2 escribe mas signal, mode_1 escribe menos
