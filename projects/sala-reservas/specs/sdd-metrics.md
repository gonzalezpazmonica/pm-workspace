# SDD Metrics — Sala Reservas (Proyecto de Test)

> Registro histórico de rendimiento del proceso Spec-Driven Development.
> Actualizar al completar cada Spec (via `/spec:review` con `--check-impl`).
>
> **Nota:** Este es el proyecto de test del PM-Workspace. Las métricas aquí
> sirven también para validar que el proceso SDD funciona correctamente en un
> proyecto real (aunque simulado con mock data).

## Tabla de Métricas

| Sprint | Task ID | Título (corto) | Dev Type | Spec Quality | Impl OK? | Review Issues | h Estimadas | h Reales | Notas |
|--------|---------|----------------|----------|-------------|----------|---------------|------------|---------|-------|
| 2026-04 | AB101-B3 | CreateSalaCommandHandler | agent:single | ✅ Completa | ⏳ Pendiente | — | 4h | — | Spec de referencia para testing SDD |
| 2026-04 | AB102-D1 | Unit Tests Salas | agent:single | ✅ Completa | ⏳ Pendiente | — | 2h | — | Spec haiku — 15 tests |

## Instrucciones de actualización

Añadir una fila por cada Task completada vía SDD.

**Spec Quality:**
- ✅ Completa: todos los criterios de calidad cumplidos antes de implementar
- ⚠️ Incompleta: faltaban campos, el agente tuvo que detenerse
- ❌ Fallida: la Spec tenía errores que causaron fallo en implementación

**Impl OK?:**
- ✅ : Implementación correcta al primer intento (build + tests OK)
- ⚠️ : Necesitó correcciones menores (< 2 iteraciones del agente)
- ❌ : Fallida o requerió intervención humana
- ⏳ : Pendiente de ejecución

**Review Issues:** Número de issues encontrados en el Code Review humano post-agente.

---

## KPIs de SDD (calculados trimestralmente)

### Tasa de Agentización
```
Specs completadas por agente / Total specs = {N}%
Objetivo: > 65% para el Q2 2026  (target sala-reservas: 0.65)
```

### Calidad de Specs
```
Specs con quality "✅ Completa" / Total specs = {N}%
Objetivo: > 80%
```

### Tasa de Éxito de Agentes (primer intento)
```
Impl OK "✅" / Total specs de agente = {N}%
Objetivo: > 75%
```

### Ahorro de Tiempo Estimado
```
Σ(h_estimadas de specs de agente) = {N}h liberadas para trabajo de mayor valor
Sprint 1 estimado: 6h (AB101-B3: 4h + AB102-D1: 2h)
```

### Issues de Code Review por Origin
```
Specs de agente: promedio {N} issues/spec
Specs de humano: promedio {N} issues/spec
```

### Budget de Tokens (Sprint 2026-04)
```
Budget: $15 USD
Consumido: $0 (pendiente de ejecución)
Restante: $15 USD
```

---

## Historial de Mejoras al Template

| Fecha | Cambio | Causa | Sprint |
|-------|--------|-------|--------|
| 2026-03-01 | Versión inicial del template | Setup SDD — proyecto de test | — |

---

## Reglas de Iteración (SDD Fase 5)

Si un agente produce > 2 issues bloqueantes en Code Review:
1. Documentar aquí qué faltó en la Spec
2. Mejorar la plantilla `spec-template.md` o estas guías
3. Considerar mover esa categoría de task a `human` temporalmente

**Principio fundamental:** _"Si el agente falla, la Spec no era suficientemente buena"_

---

## Specs del Proyecto de Test

Las siguientes specs están disponibles para testear el flujo SDD completo:

| Spec File | Task | Modelo | Propósito del Test |
|-----------|------|--------|--------------------|
| `AB101-B3-create-sala-handler.spec.md` | AB#101-B3 | claude-opus-4-5-20251101 | Testear flujo agent:single para handler CQRS |
| `AB102-D1-unit-tests-salas.spec.md` | AB#102-D1 | claude-haiku-4-5-20251001 | Testear flujo agent:single para unit tests |

Para ejecutar un agente sobre estas specs (cuando el proyecto real exista):
```bash
# Lanzar agente implementador
claude --model claude-opus-4-5-20251101 \
  --system-prompt "$(cat projects/sala-reservas/CLAUDE.md)" \
  --max-turns 40 \
  "$(cat projects/sala-reservas/specs/sprint-2026-04/AB101-B3-create-sala-handler.spec.md)" \
  2>&1 | tee output/agent-runs/AB101-B3-$(date +%Y%m%d-%H%M).log

# Lanzar agente tester
claude --model claude-haiku-4-5-20251001 \
  --system-prompt "$(cat projects/sala-reservas/CLAUDE.md)" \
  --max-turns 30 \
  "$(cat projects/sala-reservas/specs/sprint-2026-04/AB102-D1-unit-tests-salas.spec.md)" \
  2>&1 | tee output/agent-runs/AB102-D1-$(date +%Y%m%d-%H%M).log
```
