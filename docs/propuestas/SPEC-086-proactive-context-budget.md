---
spec_id: SPEC-086
title: Proactive Context Budget Tracker — pre-call check
status: Implemented
origin: Claudepedia pattern analysis (2026-04-08)
severity: Media
effort: ~3h
---

# SPEC-086: Proactive Context Budget Tracker

## Problema

Nuestro sistema de gestion de contexto es reactivo: `context-health.md` define
4 zonas y sugiere /compact tras cada comando. Pero la comprobacion ocurre
DESPUES de consumir contexto, no ANTES de la llamada al LLM.

Claudepedia documenta un patron proactivo: un `ContextBudgetTracker` que
verifica ANTES de cada llamada, con dual threshold (80% standard + 95%
emergency) y circuit breaker tras 3 fallos consecutivos de compactacion.

El resultado: el modelo siempre recibe un contexto gestionado, no uno
que ya ha desbordado.

## Solucion

1. Script `scripts/context-budget-check.sh` que:
   - Lee el porcentaje de contexto actual (env `CLAUDE_CONTEXT_USAGE_PCT` si disponible, o estimacion)
   - Aplica dual threshold: 80% → standard compact, 95% → emergency (solo trim, sin LLM)
   - Circuit breaker: si 3 compactaciones consecutivas no reducen por debajo del umbral, no reintentar
   - Devuelve accion: `NO_ACTION | STANDARD_COMPACT | EMERGENCY_COMPACT | CIRCUIT_OPEN`

2. Hook PreToolUse (async, no bloqueante) que registra el estado del budget
   antes de operaciones pesadas (Task, Agent)

3. Actualizar `context-health.md` con el patron proactivo documentado

## Criterios de aceptacion

- [ ] Script `context-budget-check.sh` implementado con dual threshold
- [ ] Circuit breaker funcional (3 fallos → para)
- [ ] Emergency compact: solo trim tool results + drop oldest, sin LLM call
- [ ] Tests BATS con >= 8 casos (thresholds, circuit breaker, reset)
- [ ] `context-health.md` actualizado con patron proactivo
