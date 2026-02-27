# Fase 4-5: Review, Validación y Métricas de SDD

## Fase 4 — Review y Validación Post-Implementación

Independientemente de si implementó un humano o un agente:

### 4.1 Checklist de review para el Tech Lead

```markdown
## Review Checklist — AB#{task_id} — {título}

### Verificación contra Spec
- [ ] Todos los ficheros listados en la Spec han sido creados/modificados
- [ ] Las firmas de métodos/clases coinciden exactamente con el contrato de la Spec
- [ ] Todas las reglas de negocio de la Spec están implementadas
- [ ] Los test scenarios descritos en la Spec tienen su test correspondiente
- [ ] Los tests pasan en el pipeline CI

### Calidad de código
- [ ] El código sigue los patrones del proyecto (detectados en Fase 1.3)
- [ ] Sin hardcoding de valores que deberían ser configurables
- [ ] Manejo de errores implementado (no solo happy path)
- [ ] Sin código comentado ni TODOs sin resolver

### Específico para implementaciones de agente
- [ ] El agente no tomó decisiones de diseño fuera de la Spec
- [ ] No hay código generado innecesario (el agente tiende a añadir más de lo pedido)
- [ ] Las dependencias inyectadas coinciden con el patrón de inyección del proyecto
- [ ] Los nombres de clases/métodos siguen las convenciones del proyecto
```

### 4.2 Actualizar el work item en Azure DevOps

```bash
PAT=$(cat $AZURE_DEVOPS_PAT_FILE)

# Mover la Task a "In Review" (si la implementó un agente, el estado lo cambia el agente al terminar)
curl -s -u ":$PAT" \
  -H "Content-Type: application/json-patch+json" \
  -X PATCH \
  "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/{task_id}?api-version=7.1" \
  -d '[
    {"op": "replace", "path": "/fields/System.State", "value": "In Review"},
    {"op": "add", "path": "/fields/System.Tags", "value": "spec-driven,agent-implemented"},
    {"op": "add", "path": "/fields/Microsoft.VSTS.Scheduling.CompletedWork", "value": {horas_reales}}
  ]'
```

---

## Fase 5 — Aprendizaje y Mejora Continua

### 5.1 Métricas de SDD

Registrar en `projects/{proyecto}/specs/sdd-metrics.md`:

```markdown
| Sprint | Task ID | Developer Type | Spec Quality | Impl OK? | Review Issues | Horas Est | Horas Real |
|--------|---------|---------------|--------------|----------|---------------|-----------|------------|
| 2026-04 | AB#1234-B3 | agent-single | ✅ Completa | ✅ | 0 | 4h | 3.5h |
| 2026-04 | AB#1234-D1 | agent-single | ✅ Completa | ✅ | 1 (naming) | 3h | 2h |
| 2026-04 | AB#1235-B3 | human | ✅ Completa | ✅ | 0 | 6h | 7h |
```

**Columnas a registrar:**
- **Sprint**: Identificador del sprint (ej: 2026-04)
- **Task ID**: Identificador único del task en Azure DevOps (ej: AB#1234-B3)
- **Developer Type**: `human`, `agent-single`, o `agent-team`
- **Spec Quality**: ✅ Completa, 🟡 Parcial, ❌ Incompleta
  - Completa = todos los 7 puntos de 4.2 cumplidos
  - Parcial = 5-6 puntos cumplidos
  - Incompleta = < 5 puntos
- **Impl OK?**: ✅ Pasó review, ⚠️ Cambios menores, ❌ Rechazada
- **Review Issues**: Número de issues encontrados en review
- **Horas Est**: Estimadas en la Spec
- **Horas Real**: Horas reales gastadas (incluir code review si aplica)

### 5.2 Regla de iteración

Si un agente produce código que el reviewer rechaza (> 2 issues bloqueantes):
→ Documentar qué faltó en la Spec y mejorar la plantilla/guidelines
→ Considerar mover esa categoría de task a `human` hasta que la Spec mejore

Principio: **"Si el agente falla, la Spec no era suficientemente buena"**

---

## Análisis de Métricas

### Velocidad de Agentes vs Humanos

```
tiempo_agente = tiempo_spec_writing + tiempo_agente_execution + tiempo_review
tiempo_humano = tiempo_spec_reading + tiempo_implementation + tiempo_review

Si tiempo_agente < tiempo_humano → usar agente en sprints futuros
Si tiempo_agente > tiempo_humano → mejorar Spec y reintentar
```

### Tasa de Éxito de Specs

```
tasa_exito = (tasks_impl_ok / tasks_totales) * 100

< 50% → Specs muy ambiguas, mejorar plantilla
50-75% → Specs mejorables, analizar issies comunes
> 75% → Specs bien definidas, mantener nivel
= 100% → Specs excelentes, puede relajar algunos puntos de calidad
```

### Deuda Técnica Generada por Agentes

```
deuda = (issues_rechazadas + issues_code_review) / tasks_agente

Monitorear si agentes generan más deuda que humanos.
Si deuda_agentes > 1.5 × deuda_humanos → análisis de root cause.
```

---

## Dashboard Recomendado

Mantener en `projects/{proyecto}/` un dashboard actualizado:

```markdown
# SDD Dashboard — {proyecto}

## Métricas Acumuladas

| Métrica | Valor | Tendencia |
|---------|-------|-----------|
| Tasks implementadas | 47 | ↑ |
| % Agente vs Humano | 68% agente, 32% humano | ↑ agente |
| Tasa éxito Specs | 87% | ↑ |
| Tiempo promedio Task | 4.2h | ↓ |
| Deuda técnica media | 0.3 issues | ↓ |

## Top Issues en Specs

1. **Ambigüedad en criterios de aceptación** — 8 ocurrencias
   → Mejorar plantilla: añadir sección "Edge Cases Explícitos"

2. **Faltan ejemplos de código de referencia** — 5 ocurrencias
   → Policy: siempre incluir 2+ ejemplos de código similar

3. **Inconsistencia con patrones de proyecto** — 3 ocurrencias
   → Analizar si el proyecto tiene nuevos patrones no documentados

## Próximos pasos

- Mejorar Spec template con sección "Edge Cases"
- Crear library de "Referencia Code Patterns" reutilizables
- Revisar 5 specs de categoría "Backend Complex" para homogeneizar
```

---

## Mejora Continua de Specs

### Ciclo Semanal

1. **Lunes**: Revisar métricas de specs del sprint anterior
2. **Martes**: Analizar top 3 issues más frecuentes
3. **Miércoles**: Proponer mejoras en plantilla o guidelines
4. **Jueves**: Actualizar template de Spec
5. **Viernes**: Documentar aprendizajes en `sdd-retrospective.md`

### Actualización de Plantilla

Cuando se identifica un patrón de failure:

```markdown
## Cambio en Spec Template

### Antes
[Sección antigua]

### Después
[Sección mejorada con ejemplo/clarificación]

### Motivo
Detectamos que {N} specs fallaron porque [razón].
Esta clarificación evitará {problema} en futuras specs.

### Versión
v2.3 — 2026-02-27
```

---

## Escalada de Issues de Review

### Bloqueos Críticos
- Spec deficiente → rechazar, pedir reescritura
- Security issues → escalate a `security-guardian`
- Arquitectura incorrecta → escalate a `architect`

### Issues Menores
- Naming no coincide → Hacer rápido fix en code review
- Tests incompletos → Pedir al implementador completar
- Documentación faltante → Task separada para tech-writer

### Patrón de Escalada
1. Review identifica issue
2. Si bloqueante → rechazar, detallar en feedback
3. Si menor → aceptar con comentarios
4. Si patrón sistémico → analizar en retrospective, mejorar Spec
