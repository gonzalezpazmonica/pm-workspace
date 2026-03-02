---
name: sprint-autoplan
description: Planificación inteligente de sprint — sugiere composición óptima desde backlog y capacidad
developer_type: all
agent: task
context_cost: high
---

# /sprint-autoplan

> 🦉 Savia compone el sprint ideal balanceando valor, capacidad y riesgo.

---

## Cargar perfil de usuario

Grupo: **Sprint & Daily** — cargar:

- `identity.md` — nombre
- `workflow.md` — planning_cadence
- `projects.md` — proyecto target
- `tone.md` — alert_style, celebrate

---

## Subcomandos

- `/sprint-autoplan` — propuesta completa de sprint con justificación
- `/sprint-autoplan --conservative` — prioriza items de bajo riesgo
- `/sprint-autoplan --ambitious` — maximiza valor asumiendo capacidad plena
- `/sprint-autoplan --what-if {SP}` — simula con capacidad personalizada

---

## Flujo

### Paso 1 — Recopilar inputs

1. **Capacidad**: leer equipo disponible, vacaciones, % dedicación
2. **Velocity histórica**: últimos 3-5 sprints (media, desviación)
3. **Backlog priorizado**: PBIs en estado Approved/Committed, ordenados por prioridad
4. **Dependencias**: PBIs bloqueados o con dependencias externas
5. **Deuda técnica**: items de debt presupuestados para este sprint

### Paso 2 — Algoritmo de selección

```
Inputs:
  - Capacity = {SP disponibles} (velocity media - 1 desviación)
  - Backlog = PBIs ordenados por (Business Value × urgencia)
  - Constraints = dependencias, skills requeridos, debt budget

Algoritmo:
  1. Reservar {debt_budget}% para deuda técnica
  2. Seleccionar PBIs por prioridad hasta llenar capacidad
  3. Verificar dependencias: si un PBI depende de otro no seleccionado → incluir o excluir ambos
  4. Verificar skills: si un PBI requiere skill no disponible → marcar riesgo
  5. Balancear: ≥1 item de alto valor + items menores para flexibilidad
```

### Paso 3 — Presentar propuesta

```
📋 Sprint Autoplan — Sprint {N} ({fecha inicio} — {fecha fin})

  Capacidad estimada: {SP} SP (velocity: {media} ± {desviación})
  Items propuestos: {N} PBIs + {N} Debt items

  🟢 Alta confianza:
    - PBI#1234 "Feature X" (5 SP) — prioridad alta, sin dependencias
    - PBI#1235 "Feature Y" (3 SP) — prioridad alta, skill disponible

  🟡 Riesgo medio:
    - PBI#1236 "Feature Z" (8 SP) — depende de API externa

  🔧 Deuda técnica ({debt_budget}%):
    - DEBT#789 "Refactor auth module" (3 SP)

  📊 Resumen:
    SP planificados: {N}/{capacity} ({%} utilización)
    Valor total estimado: {BV sum}
    Items con riesgo: {N}
```

### Paso 4 — Alternativas

Presentar 2 alternativas al plan principal:
- **Conservador**: -20% SP, solo items sin riesgo
- **Ambicioso**: +10% SP, incluye items de riesgo medio

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: sprint_autoplan
sprint: "Sprint 2026-08"
capacity_sp: 42
planned_sp: 38
items: 7
debt_items: 2
risk_items: 1
utilization: 90%
```

---

## Restricciones

- **NUNCA** planificar por encima del 95% de capacidad
- **NUNCA** omitir el presupuesto de deuda técnica
- **NUNCA** asignar items sin verificar disponibilidad del skill
- La propuesta es una SUGERENCIA — el PM/PO decide el sprint final
- Siempre presentar alternativas para que el PM tenga opciones
