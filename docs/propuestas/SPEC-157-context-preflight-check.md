---
id: SPEC-157
title: Context Pre-Flight Check
status: IMPLEMENTED
priority: HIGH
estimated_hours: 6
tier: 1B
origin: anthropic-effective-agents-thesis-2026
depends_on: [SPEC-156]
---

# SPEC-157 Context Pre-Flight Check

## Problema
Agentes cargan contexto sin validar si excede su token_budget (SPEC-156). Resultado: invocaciones que fallan a mitad de ejecucion o consumen 2x el presupuesto, sin posibilidad de split previo.

## Solucion
Hook PreToolUse en Task que:
1. Lee token_budget del agente target (frontmatter SPEC-156)
2. Estima tokens de inputs (prompt, files referenced, skills loaded)
3. Si proyeccion > 80% budget: warn + sugiere compactacion
4. Si proyeccion > 100% budget: block + exige split de tarea

## Slices
1. Estimador de tokens por input source (2h)
2. Hook PreToolUse con clasificacion warn/block (2h)
3. Sugerencias automaticas de split y tests (2h)

## AC
- Estimacion +-15% del consumo real (validado contra 20 invocaciones reales)
- Warn a 80%, block a 100% del budget
- Sugiere skills de compactacion (context-rot-strategy, context-task-classifier)
- Overhead < 2k tokens por preflight
- Cache por hash de input para evitar re-estimar

## Riesgos
Latencia anadida en cada Task. Mitigacion: cachear estimaciones por hash de input + benchmark p95 < 500ms.

## Out of scope
Compactacion automatica sin aprobacion humana. Split automatico de specs.
