---
name: ai-incident
description: Registrar y analizar incidentes donde recomendaciones de Savia fueron incorrectas
developer_type: all
agent: task
context_cost: medium
---

# /ai-incident

> 🦉 Los errores de Savia son datos. Aprendemos de ellos para mejorar.

Registrar, categorizar y analizar incidentes donde las recomendaciones o acciones de Savia fallaron o fueron incorrectas.

---

## Categorías de Incidentes

- **BIAS** — Savia favoreció un resultado sin justificación objetiva
- **HALLUCINATION** — Savia inventó datos o asumió hechos sin verificar
- **CONTEXT-LOSS** — Savia olvidó o ignoró información crítica
- **OUTDATED** — Savia usó datos desactualizados
- **BOUNDARY-VIOLATION** — Savia excedió sus límites definidos
- **CONFIDENCE-MISMATCH** — Confianza mostrada alta pero resultado incorrecto

---

## Flujo de Registro

```
/ai-incident new
```

Savia presenta formulario interactivo:

1. **¿Qué sucedió?** — descripción breve del incidente
2. **¿Cuándo?** — fecha aproximada
3. **¿Qué recomendó Savia?** — recomendación original
4. **¿Qué era lo esperado?** — resultado correcto
5. **¿Impacto?** — bajo/medio/alto/crítico
6. **¿Categoría?** — bias/hallucination/context-loss/outdated/boundary-violation/confidence-mismatch
7. **Detalles adicionales** — evidencia o contexto

---

## Análisis Automático

Tras 5+ incidentes registrados:

```
/ai-incident analyze
```

Genera:
- **Estadísticas**: total, resueltos, abiertos, tasa
- **Top categorías**: frecuencia de cada tipo
- **Tendencias**: patrones (ej: "sprint-planning es el comando más propenso a errores")
- **Recomendaciones**: acciones para mejorar (cargar datos faltantes, reducir confianza, etc.)

---

## Comandos

```bash
/ai-incident list [--proyecto] [--categoría] [--días N]
/ai-incident view {id}
/ai-incident search "{texto}"
/ai-incident analyze [--últimos N]
/ai-incident export [--formato csv|json|md]
```

---

## Integración con AI Safety

Los incidentes informan automáticamente:
- **Recalibración de confianza**: si recomendaciones de tipo X tienen alto % de incidentes, bajar confianza
- **Actualización de límites**: si un límite se viola frecuentemente, considerarlo
- **Mejora de context-map**: si hay context-loss recurrente, cargar más datos
- **Alertas**: "Has tenido 3 incidentes en asignaciones — Savia pedirá validación extra"

---

## Almacenamiento

```
projects/{proyecto}/incidents/
├── ai-incidents.md      ← Log de incidentes
├── incidents.json       ← Index para búsquedas
└── analysis/
    ├── 2026-03.md
    └── 2026-02.md
```

---

## Restricciones

- **NUNCA** ocultar incidentes
- **NUNCA** auto-eliminar sin revisión humana
- **NUNCA** cambiar categoría sin justificación
- **SIEMPRE** documentar raíz del incidente
- **SIEMPRE** proponer acciones correctivas
- Usar para APRENDER, no para penalizar

---

## Configuración

En `company/policies.md`:

```yaml
incidents:
  auto_register: false
  require_human_validation: true
  analyze_threshold: 5
  auto_fix_if_low_impact: true
  notification_on_new: true
```

Ver **@.claude/rules/domain/pm-config.md** para referencia completa.