---
name: org-metrics
description: Métricas DORA y de delivery agregadas a nivel de organización
developer_type: all
agent: task
context_cost: high
---

# /org-metrics

> 🦉 Savia agrega las métricas de todos tus proyectos para darte la foto completa.

---

## Cargar perfil de usuario

Grupo: **Reporting** — cargar:

- `identity.md` — nombre, rol, empresa
- `preferences.md` — language, report_format, date_format
- `projects.md` — todos los proyectos
- `tone.md` — formality

---

## Subcomandos

- `/org-metrics` — dashboard completo con métricas agregadas
- `/org-metrics --dora` — solo métricas DORA agregadas
- `/org-metrics --teams` — desglose por equipo
- `/org-metrics --trend {N}` — evolución de los últimos N sprints

---

## Flujo

### Paso 1 — Recopilar métricas por proyecto

Para cada proyecto activo, ejecutar internamente `/kpi-dora` y `/kpi-dashboard`:

- Deployment Frequency, Lead Time for Changes, MTTR, Change Failure Rate
- Velocity, Sprint Goal Achievement, Escape Rate
- Team utilization, WIP, Cycle Time

### Paso 2 — Agregar a nivel organizacional

```
📊 Org Metrics — {empresa} — {fecha}

  DORA (promedio org):
  ├─ Deployment Frequency: {N}/semana ({élite/high/medium/low})
  ├─ Lead Time for Changes: {N} horas ({nivel})
  ├─ MTTR: {N} horas ({nivel})
  └─ Change Failure Rate: {N}% ({nivel})

  Delivery:
  ├─ Velocity total: {N} SP/sprint (across {N} teams)
  ├─ Sprint Goal Achievement: {N}%
  └─ Escape Rate: {N}%

  Health:
  ├─ Teams on track: {N}/{total} 🟢
  ├─ Teams at risk: {N}/{total} 🟡
  └─ Teams blocked: {N}/{total} 🔴
```

### Paso 3 — Desglose comparativo (sin ranking)

| Proyecto | Velocity | DORA Level | Sprint Goal | Trend |
|---|---|---|---|---|
| {proyecto-A} | {SP} | Elite | 95% | 📈 |
| {proyecto-B} | {SP} | High | 80% | ➡️ |
| {proyecto-C} | {SP} | Medium | 65% | 📉 |

**No rankear equipos.** Mostrar métricas sin comparación valorativa.

### Paso 4 — Tendencias y alertas

```
📈 Tendencias (últimos {N} sprints)

  Velocity org: +8% ↑ (estable)
  Lead Time: -12% ↓ (mejorando)
  Change Failure Rate: +3% ↑ (⚠️ atención)

⚠️ Alertas org:
  - Change Failure Rate subiendo 3 sprints consecutivos
  - Proyecto-C por debajo del umbral DORA "Medium"
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: org_metrics
projects: 5
dora_level: "High"
velocity_total: 187
sprint_goal_avg: 82%
teams_on_track: 3
teams_at_risk: 1
teams_blocked: 1
```

---

## Restricciones

- **NUNCA** rankear equipos — mostrar datos, no clasificaciones
- **NUNCA** usar métricas para culpar — tono siempre constructivo
- **NUNCA** comparar developers individuales entre proyectos
- Si un proyecto no tiene datos DORA → indicar "sin datos" en vez de inventar
- Métricas son para decisiones estratégicas, no para microgestión
