---
name: graph-impact
description: Analiza el impacto en cascada de cambios en entidades PM
allowed-tools:
  - Read
  - Grep
  - Bash
context_cost: medium
---

# /graph-impact {change}

Calcula el impacto en cascada de cambiar una entidad PM.

## Ejemplos

- `/graph-impact "remove member Alice"` — ¿A qué tareas afecta?
- `/graph-impact "delay Task AB#123 by 1 week"` — ¿Qué sprints se desvían?
- `/graph-impact "change decision ADR-5"` — ¿Cuántas tareas se replantean?
- `/graph-impact "critical risk R001 materializes"` — ¿Quién es dueño? ¿Mitigación?

## Ejecución

1. 🏁 Banner: `══ /graph-impact ══`
2. **Parsear cambio**
   - Tipo: remove member, delay task, change decision, risk materialized
   - Entidad afectada y parámetros
3. **Calcular cascada**
   - Buscar todas las relaciones (incoming + outgoing) de la entidad
   - Seguir chain hasta encontrar impactos finales (tasks, sprints)
   - Contar entidades impactadas
4. **Mostrar impacto**
   - Árbol de cambios: raíz → intermedias → finales
   - Para cada nivel: número de entidades, severidad
   - Recomendaciones de mitigación si es crítico
5. ✅ Banner fin

## Máximo 50 líneas

Documentación comprimida. Detalles en SKILL.md.
