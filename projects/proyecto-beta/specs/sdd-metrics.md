# SDD Metrics — Proyecto Beta

> Registro histórico de rendimiento del proceso Spec-Driven Development.
> En Proyecto Beta (contrato precio fijo), el uso de agentes es prioritario para maximizar margen.

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

## KPIs de SDD — Proyecto Beta (Precio Fijo)

### Tasa de Agentización
```
Specs completadas por agente / Total specs = {N}%
Objetivo Beta: > 70% (mayor que Alpha por la presión de márgenes)
```

### Impacto en Margen del Proyecto
```
Horas liberadas por agentes × coste_hora_dev = {€} ahorrados
Coste de tokens Claude = {€}
ROI de SDD = {multiplicador}x
```

### Calidad de Specs
```
Specs con quality "✅ Completa" / Total specs = {N}%
Objetivo: > 85% (mayor exigencia en precio fijo → sin margen para correcciones)
```

### Tasa de Éxito de Agentes
```
Impl OK "✅" / Total specs de agente = {N}%
Objetivo Beta: > 80%
```

---

## Historial de Mejoras al Template

| Fecha | Cambio | Causa | Sprint |
|-------|--------|-------|--------|
| — | Versión inicial del template | Setup SDD | — |

---

## Notas específicas de Beta

- El equipo de Beta es de 2 personas → las specs de agente son críticas para la capacidad
- `assignment_weights` de Beta penaliza growth=0.00 (sin cross-training por riesgo presupuestario)
- Las specs de Beta deben ser especialmente cuidadosas en Infrastructure (Azure B2C, Blazor Server)
- El Reviewer siempre debe revisar los costes de Azure generados por el código del agente

**Principio fundamental:** _"Si el agente falla, la Spec no era suficientemente buena"_
