# SDD Metrics — Proyecto Alpha

> Registro histórico de rendimiento del proceso Spec-Driven Development.
> Actualizar al completar cada Spec (via `/spec-review` con `--check-impl`).

## Tabla de Métricas

| Sprint | Task ID | Título (corto) | Dev Type | Spec Quality | Impl OK? | Review Issues | h Estimadas | h Reales | Notas |
|--------|---------|----------------|----------|-------------|----------|---------------|------------|---------|-------|
| — | — | — | — | — | — | — | — | — | Primer sprint con SDD |

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

**Review Issues:** Número de issues encontrados en el Code Review humano post-agente.

---

## KPIs de SDD (calculados trimestralmente)

### Tasa de Agentización
```
Specs completadas por agente / Total specs = {N}%
Objetivo: > 60% para el Q2 2026
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
```

### Issues de Code Review por Origin
```
Specs de agente: promedio {N} issues/spec
Specs de humano: promedio {N} issues/spec
```

---

## Historial de Mejoras al Template

| Fecha | Cambio | Causa | Sprint |
|-------|--------|-------|--------|
| — | Versión inicial del template | Setup SDD | — |

---

## Reglas de Iteración (SDD Fase 5)

Si un agente produce > 2 issues bloqueantes en Code Review:
1. Documentar aquí qué faltó en la Spec
2. Mejorar la plantilla `spec-template.md` o estas guías
3. Considerar mover esa categoría de task a `human` temporalmente

**Principio fundamental:** _"Si el agente falla, la Spec no era suficientemente buena"_
