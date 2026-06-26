---
id: SPEC-165
title: World-model simulation for pre-action validation
status: IMPLEMENTED
priority: MEDIUM
estimated_hours: 12
tier: 2
origin: lecun-jepa-h-research-2026
---

# SPEC-165 World-Model Simulation

## Problema
Savia ejecuta acciones (Edit, Write, Bash, Task) sin simular consecuencias previas. El tribunal valida POST-action (cuando el archivo ya esta escrito, el comando ya corrido). LeCun: el gap mas grande del stack actual respecto a H-JEPA es la ausencia de **world model** que prediga el estado tras una accion antes de ejecutarla.

Hoy, una edicion mal planteada solo se detecta cuando un hook falla o un test rompe. Pagamos el coste de la accion + el coste del rollback.

## Solucion
Pre-action simulator que para acciones de alto coste (Edit en archivos > 500 lineas, Bash con efectos en disco, Task heavy-tier) predice:

- Estado esperado del workspace tras la accion
- Probabilidad de violacion de reglas (Rule #11 lineas, Rule #20 PII, Rule #22 size)
- Probabilidad de fallo de test downstream
- Coste estimado en tokens del rollback si falla

Implementacion v1 (cheap): heuristica + dry-run estatico (parse AST, simular escritura sin escribir, ejecutar linters/validadores).
Implementacion v2 (futura): LLM-as-simulator con JEPA-style latent prediction.

## Slices
1. Schema de "action proposal" + dry-run para Write/Edit (4h)
2. Predictor de violacion de reglas (regex + counts sin escritura) (3h)
3. Hook PreToolUse que ejecuta simulator y aborta si prob_violation > umbral (3h)
4. Tests BATS + telemetria `output/world-model-predictions.jsonl` (2h)

## AC
- Simulator detecta >= 80% de violaciones Rule #11 antes de escribir
- Simulator detecta >= 70% de violaciones Rule #22 antes de escribir
- Falsos positivos < 10% en muestra de 100 acciones reales
- Latencia simulator < 500ms para Edit/Write
- Tests BATS score >= 80

## Riesgos
- Latencia: simulator que tarda > 1s degrada UX a humanos
- Mitigacion: skip simulator para acciones triviales (< 50 lineas, no en .claude/)
- Sobreajuste a reglas conocidas y miss de violaciones nuevas
- Mitigacion: el tribunal POST-action sigue activo como red de seguridad

## Out of scope
- Simulator semantico de codigo (rompe X test Y → fuera de scope v1)
- LLM-as-simulator (v2, requiere infra y tokens significativos)
- Simulator para Bash arbitrario (deferido)

## Origen
LeCun H-JEPA: el actor propone, el world-model predice, el critic evalua la prediccion, y solo entonces el actor ejecuta. Savia actual brinca del actor directo al critic post-hoc.

## Trabajo relacionado
- Complementa SPEC-156 (budget) y SPEC-157 (context preflight) — son simuladores parciales sobre dimensiones especificas
- Habilita actor-iterative-pre-action (deferido en SPEC-163): con world-model, el actor puede iterar antes de ejecutar
