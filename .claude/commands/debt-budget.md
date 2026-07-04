---
name: debt-budget
description: >
  Propone porcentaje del sprint a dedicar a deuda técnica basado
  en tendencias de velocity y rework. Incluye justificación y proyección.
developer_type: agent-single
agent: business-analyst
context_cost: low
tier: extended
---

# Debt Budget

**Argumentos:** $ARGUMENTS

> Uso: `/debt-budget --project {p}` o `/debt-budget --project {p} --sprints-history 10`

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Architecture & Debt** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/preferences.md`
3. Adaptar profundidad del análisis según `preferences.detail_level`
4. Si no hay perfil → continuar con comportamiento por defecto

## 2. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💰 /debt-budget — Propuesta de presupuesto de deuda
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 3. Parámetros

- `--project {nombre}` — Proyecto (obligatorio)
- `--sprints-history {N}` — Histórico a analizar (default: 10)

## 4. Leer datos

1. Histórico de velocity (últimos N sprints) de `/velocity-trend`
2. Tasa de rework (de agent traces o burndown analysis)
3. Output de `/debt-prioritize --project {p}` (items priorizados)

## 4. Heurística de recomendación

```
SI velocity declinando + rework aumentando
  → RECOMENDAR: 20-30% presupuesto deuda
SI velocity estable + rework estable
  → RECOMENDAR: 10-15% presupuesto deuda
SI velocity aumentando + rework bajo
  → RECOMENDAR: 5-10% presupuesto deuda (mantenimiento)
```

**Ejemplos:**
- Velocity 45 → 40 → 38 (↓) + Rework 12% → 16% (↑) = 25% deuda
- Velocity 45 → 46 → 45 (→) + Rework 8% → 8% (→) = 12% deuda
- Velocity 42 → 48 → 50 (↑) + Rework 5% → 3% (↓) = 7% deuda

## 5. Formato de salida

```
## Presupuesto de Deuda — {proyecto} — {fecha}

### Recomendación
**Presupuesto**: 18% del sprint (≈ 8 horas de 45h capacity)

### Justificación
- Velocity: 45 → 40 → 38 (declinando 2-3 puntos/sprint) 📉
- Rework: 12% → 16% (incrementando) ⚠️
- Recomendación: Invertir ahora para evitar caída mayor

### Items a Incluir
(De `/debt-prioritize`, los que caben en 8h)
1. AuthController refactor — 8h — Fix authentication bugs
   - Evita: estimado 3h rework/sprint → 12h en 4 sprints
   - ROI: 4:1

### Proyección de Impacto
**Si aprobamos 18% deuda este sprint:**
- Sprint actual: -8h features, +8h deuda = 37h features
- Sprint siguiente (proyectado): +15h features (rework reducido)
- Acumulado 2 sprints: +3h features vs sin deuda presupuestada

**Si NO hacemos deuda:**
- Velocity sigue cayendo → 35 → 32 → 28
- Rework sigue subiendo → 18% → 20% → 24%
- Acumulado 2 sprints: -8h features

### Historial de Recomendaciones
| Sprint | % Recomendado | % Aprobado | Velocity Post |
|---|---|---|---|
| Sprint 25 | 15% | 12% | 42 → 41 (sigue bajando) |
| Sprint 26 | 18% | 18% | 41 → 40 (estable) |
| Sprint 27 | 20% | 20% | 40 → 42 (↑ mejora) |

Tendencia: Al acercarnos a 20%, velocity se estabiliza/mejora ✅
```

## 6. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /debt-budget — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Presupuesto: projects/{proyecto}/debt/budget-{fecha}.md
⏱️  Duración: ~30s
→ Siguiente: `/sprint-plan` incluir items propuestos
```
