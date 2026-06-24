---
id: SPEC-159
title: Async Tribunal Fan-out
status: IMPLEMENTED
priority: MEDIUM
estimated_hours: 8
tier: 2D
origin: anthropic-effective-agents-thesis-2026
---

# SPEC-159 Async Tribunal Fan-out

## Problema
court-orchestrator y truth-tribunal-orchestrator invocan jueces secuencialmente. Wall-time: 4 jueces x 30s = 2min para tribunal completo. Anthropic recomienda fan-out async para reducir latencia cuando los jueces son independientes.

## Solucion
Refactor orchestradores para lanzar jueces en paralelo via Promise.all + agregacion al completar todos. Mantiene semantica de vetos (cualquier juez con BLOCK aborta la decision).

## Slices
1. Refactor court-orchestrator a async (3h)
2. Refactor truth-tribunal-orchestrator a async (3h)
3. Tests + medicion wall-time antes/despues (2h)

## AC
- Wall-time reducido 60%+ (medido con benchmark)
- Semantica de vetos preservada (BLOCK de cualquier juez aborta)
- Tests existentes no regresan
- Logs muestran tiempos por juez individuales + total
- Timeout por juez (default 60s) con fallback a juicio individual si timeout

## Riesgos
Cambio en semantica si un juez falla mid-flight. Mitigacion: timeout por juez + fallback a juicio individual (sequential mode bajo flag SAVIA_TRIBUNAL_MODE=sync).

## Out of scope
Cambiar el conjunto de jueces. Anadir nuevos jueces. Modificar logica de agregacion (vetos vs mayorias).
