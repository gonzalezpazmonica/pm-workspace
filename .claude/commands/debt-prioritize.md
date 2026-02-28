---
name: debt-prioritize
description: >
  Priorización de deuda por impacto de negocio, frecuencia de cambio
  y proximidad a PBIs. Scoring configurable, sugerencias de roadmap.
developer_type: agent-single
agent: architect
context_cost: medium
---

# Debt Prioritize

**Argumentos:** $ARGUMENTS

> Uso: `/debt-prioritize --project {p}` o `/debt-prioritize --project {p} --next-sprints 2`

## 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ /debt-prioritize — Priorización de deuda
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Parámetros

- `--project {nombre}` — Proyecto (obligatorio)
- `--next-sprints {N}` — Sprints a considerar (default: 2)

## 3. Leer entrada

1. Leer `projects/{proyecto}/debt/analysis-*.md` (más reciente)
2. Leer `projects/{proyecto}/CLAUDE.md` (context del proyecto)
3. Leer `projects/{proyecto}/backlog.md` (PBIs próximos sprints)

Si no existe analysis → ejecutar `/debt-analyze --project {p}` automáticamente

## 4. Scoring de prioridad (configurable, pesos por defecto)

```
Score = (Business Impact × 0.40) +
        (Change Frequency × 0.30) +
        (Team Velocity Impact × 0.20) +
        (Risk × 0.10)
```

- **Business Impact (40%)**: ¿Qué PBIs del backlog próximo toca este fichero?
  - Si fichero está en scope de 1-2 próximos sprints → +100 puntos
  - Si no → +20 puntos

- **Change Frequency (30%)**: ¿Cuántos cambios últimos 30/60/90 días?
  - Churn > 10/período → +100 puntos
  - Churn 5-10 → +60 puntos
  - Churn 1-4 → +30 puntos

- **Team Velocity Impact (20%)**: Estimación de rework evitado
  - Si refactorizar reduce rework en 2+ sprints → +80 puntos
  - Si reduce en 1 sprint → +50 puntos

- **Risk (10%)**: ¿Es seguridad, datos, crítico?
  - Security/Data vulnerability → +100 puntos
  - Business-critical → +70 puntos
  - Estándar → +30 puntos

## 5. Formato de salida

```
## Deuda Priorizada — {proyecto} — {fecha}

### Top 5 Items Prioritarios (próximos 2 sprints)

| Rank | Fichero | Score | Impacto | Frecuencia | PBIs | Effort | ROI |
|---|---|---|---|---|---|---|---|
| 1 | AuthController.cs | 88/100 | ⭐⭐⭐ Alto | 18/30d | AB#234 | 8h | Muy alto |
| 2 | PaymentService.cs | 76/100 | ⭐⭐ Medio | 8/30d | AB#267 | 6h | Alto |
| 3 | Legacy.cs | 64/100 | ⭐ Bajo | 2/30d | — | 12h | Bajo |

### Recomendación de Sprint Backlog

**Sprint Actual**: Incluir items 1-2 (14h total deuda)
- Evita rework en próximos PBIs
- Mejora velocity estimada: +5-8%

**Sprint Siguiente**: Incluir item 3 + análisis Risk
- Mantenimiento de código
- Reducción de riesgo security

### Roadmap de Deuda (12 semanas)

| Semana | Item | Horas | Propósito |
|---|---|---|---|
| 1-2 | Item 1 | 8h | Fix critical, habilita 2 PBIs |
| 3-4 | Item 2 | 6h | Reduce rework 5h/sprint |
| 5-6 | Item 3 | 12h | Risk mitigation |
| 7+ | Maintenance | 2h/sprint | Vigilancia continua |
```

## 6. Cross-referencing

- Buscar si algún item es causa de bottleneck en `/flow-metrics`
- Cruzar con `/velocity-trend` para impacto proyectado

## 7. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /debt-prioritize — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Backlog de deuda: projects/{proyecto}/debt/priorities-{fecha}.md
→ Siguiente: /debt-budget --project {proyecto}
```
