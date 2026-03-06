---
name: enterprise-metrics
description: "SPACE framework metrics, portfolio aggregation, team health indicators, Monte Carlo forecasting"
auto_load: false
paths: [".claude/commands/enterprise-dashboard*", ".claude/skills/enterprise-analytics/*"]
---

# Regla: Métricas Empresariales

> Basado en: SPACE framework (Forsgren et al., 2021), DORA metrics (Accelerate)
> Complementa: @.claude/rules/domain/pm-workflow.md

**Principio fundamental**: Medir lo que importa: velocidad entrega, calidad, satisfacción, sin caer en vanity metrics.

## SPACE Framework — 5 dimensiones

### S — Satisfaction & Wellbeing
- Team satisfaction survey (quarterly)
- Burnout risk score (weekly, anónimo)
- eNPS (Employee Net Promoter Score)
- Umbral sano: ≥ 7/10

### P — Performance
- Velocity (story points/sprint)
- Lead time (days from request to deploy)
- Deployment frequency (deployments/week)
- Change failure rate (%)
- Umbral: velocity stable ±20%, lead time < 5 días

### A — Activity
- Commits/sprint
- PR reviews completados
- Meeting time (reducir < 10% capacidad)
- Code changes (diff size, architecture impact)

### C — Communication & Collaboration
- Cross-team dependencies (% resueltos < 48h)
- Async vs sync meetings ratio (preferir async)
- Knowledge sharing (docs updated, ADRs)
- Umbral: ≥ 80% deps resuelto dentro SLA

### E — Efficiency & Flow
- WIP ratio (items in progress / finished per sprint)
- Cycle time (days from start to finish)
- Rework rate (% items reopened)
- Blocked items (tiempo blocked)
- Umbral sano: WIP ≤ 3 por persona

## Agregación Portfolio

**Portfolio Health Score** (0-100):
```
Score = (SPACE_avg × 0.5) + (Velocity_trend × 0.2) + (Risk_score × -0.3)
```

- SPACE_avg: promedio de 5 dimensiones (cada una 0-100)
- Velocity_trend: si ↑ +5%, si ↘ -10%
- Risk_score: cross-project dependencies críticas

## Health Indicators por equipo

| Métrica | Green | Amber | Red |
|---|---|---|---|
| Velocity trend | ↑ o → | ↗ o ↘ | ↓ > 20% |
| WIP ratio | ≤ 2 | 2-3 | > 3 |
| Dependency health | ≥ 80% | 60-79% | < 60% |
| Burnout risk | < 30% | 30-60% | > 60% |

## Forecasting — Monte Carlo simplificado

**Input**: últimos 5 sprints de velocity (ej: [40, 42, 38, 45, 41])

**Salida**: rango de velocidad esperado (optimista, likely, pessimista):
- Optimista: 47 SP
- Likely: 41 SP (promedio)
- Pessimista: 35 SP

**Uso**: planificación de roadmap, promises a clientes

## Integración

| Comando | Uso |
|---|---|
| `/enterprise-dashboard portfolio` | Agregación multi-proyecto |
| `/enterprise-dashboard team-health` | SPACE per equipo |
| `/enterprise-dashboard risk-matrix` | Deps cross-project |
| `/enterprise-dashboard forecast` | Predicción 2 quarters |
