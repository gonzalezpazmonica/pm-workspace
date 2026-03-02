---
name: okr-track
description: Tracking automático de progreso OKR desde métricas de sprint
developer_type: all
agent: task
context_cost: high
---

# /okr-track

> 🦉 Savia rastrea automáticamente el progreso hacia tus OKRs usando métricas de sprint.

---

## Cargar perfil

Grupo: **Reporting** — cargar:

- `company/strategy.md` — OKRs definidos
- `projects/{proyecto}/CLAUDE.md` — para cada proyecto (recopilar sprints)

---

## Subcomandos

- `/okr-track` — dashboard de progreso con semáforo (🟢🟡🔴)
- `/okr-track --objective {id}` — detalle profundo de un OKR específico
- `/okr-track --trend` — tendencia de progreso últimas 6 semanas

---

## Flujo

### Paso 1 — Leer OKRs de company/strategy.md

Extraer lista de KRs con baseline, target, fuente de medición.

### Paso 2 — Recopilar métricas de sprint

Para cada proyecto vinculado a un KR:

```
🦉 Recopilando métricas del sprint actual...
  → {proyecto}: sprint {NN}, {N} items, {SP} puntos
  → Burndown: {%} completado
  → Lead time: {dias} días promedio
```

Cálculo de avance:
- Métrica "ingresos MRR" → sumar ingresos de features completadas en proyectos
- Métrica "customers activos" → sumar DAU/MAU de features vivas
- Métrica "cobertura de tests" → promedio ponderado de cobertura en proyectos
- Métrica "time-to-market" → promedio lead time de features

### Paso 3 — Calcular progreso por KR

Fórmula general:

```
Progress % = (Actual - Baseline) / (Target - Baseline) × 100
```

Estado del semáforo:

```
🟢 Verde   — ≥85% del target alcanzado
🟡 Amarillo — 50-84% del target alcanzado
🔴 Rojo    — <50% del target alcanzado (en riesgo)
```

### Paso 4 — Presentar dashboard

```
═════════════════════════════════════════════════════════════
  🎯 OKR Tracking Dashboard
═════════════════════════════════════════════════════════════

  Objetivo 1: Dominar LATAM
  ├─ KR 1.1 — MRR 🟢 85% (Baseline: $0 → Target: $100k → Actual: $85k)
  │  Proyectos: backend-api (✓), payment-gateway (✓)
  │  Tendencia: ↗ +15% en últimas 2 semanas
  │
  ├─ KR 1.2 — Clientes activos 🟡 62% ($30k → $50k → $31k)
  │  Proyectos: mobile-app (✓)
  │  Tendencia: → Plano (sin cambio en últimas 2 semanas)
  │
  └─ KR 1.3 — Satisfaction score 🔴 35% (7.0 → 9.0 → 7.6)
     Proyectos: customer-support (?)
     Tendencia: ↘ -5% (recomendación: revisar customer-support)

  Objetivo 2: ...

  ───────────────────────────────────────────────────────────
  📊 Resumen Portfolio
    🟢 En track: 4 KRs (60%)
    🟡 En riesgo: 2 KRs (30%)
    🔴 En peligro: 1 KR (10%)

  ⚠️  Alertas
    - KR 1.3 sin datos actuales (última métrica hace 5 días)
    - Proyecto customer-support no contribuye a KR 1.3 pero aparece asociado
```

### Paso 5 — Detectar OKRs en riesgo

Señales tempranas:

- Semáforo rojo por 2+ semanas consecutivas
- Tendencia en descenso (↘) sin mitigación visible
- Proyecto vinculado sin items completados en últimas 2 sprints
- Métrica de fuente sin actualizar en >7 días

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: okr_tracking
timestamp: "2026-03-02T09:15:00Z"
okrs_on_track: {n}
okrs_at_risk: {n}
okrs_off_track: {n}
dashboard_file: "output/YYYYMMDD-okr-tracking.md"
alerts_count: {n}
```

---

## Restricciones

- **NUNCA** publicar métricas en canales no-autorizados sin confirmación
- **NUNCA** modificar OKRs automáticamente (solo mostrar progreso)
- Los datos de sprint deben estar publicados en Azure DevOps o herramienta configurada
- Métricas "privadas" (ingresos reales, datos de clientes) deben ser filtradas si el comando se ejecuta en modo "agente" para comunidad
- El tracking debe ser **una sola fuente de verdad** — validar que todas las fuentes están alineadas
