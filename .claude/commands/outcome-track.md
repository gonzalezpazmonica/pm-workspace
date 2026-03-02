---
name: outcome-track
description: Tracking de outcomes post-release — ¿la feature entregó el valor esperado?
developer_type: all
agent: task
context_cost: medium
---

# /outcome-track

> 🦉 Savia verifica si las features liberadas entregan el valor que prometieron. Outcomes, no outputs.

---

## Cargar perfil

Grupo: **Outcome Measurement** — cargar:

- `CLAUDE.md` — proyecto activo
- `projects/{proyecto}/CLAUDE.md` — releases e histórico
- `company/strategy.md` — OKRs esperados
- `projects/{proyecto}/outcomes-register.md` (si existe)
- Últimas 3 releases: fechas, features, metrics pre/post

---

## Subcomandos

- `/outcome-track` — tracking interactivo de últimas 3 releases
- `/outcome-track --release {vX.Y.Z}` — detalle de una release específica
- `/outcome-track --register` — crear/actualizar outcomes-register.md
- `/outcome-track --gap` — mostrar releases sin outcomes definidos

---

## Flujo

### Paso 1 — Identificar releases recientes

Buscar releases en últimos 3 meses. Para cada release, recopilar:

```
Release: v1.2.0
Fecha: 2026-01-15
Features: #2341 (Feature X), #2342 (Enhancement Y), #2350 (Bug fix Z)
Métricas pre-release (7 días antes): {baseline}
Métricas post-release (7 días después, 30 días después): {datos}
```

### Paso 2 — Definir expected outcomes

Para cada feature: métrica, baseline, target esperado, importancia.

Guardar en `projects/{proyecto}/outcomes-register.md`:

```markdown
## Release v1.2.0 — 2026-01-15

### Feature #2341 — Login SSO
- Métrica: Tiempo de login
- Baseline: 45s | Target: 15s | Importancia: Critical

### Feature #2342 — Dashboard
- Métrica: Adoption % | Baseline: 0% | Target: 40% @ 30d | High
```

### Paso 3 — Recopilar datos actuales

Métricas post-release: 7 días + 30 días vs baseline y target.

### Paso 4 — Calcular outcome delivery rate

`(Logradas + 0.5×En Progreso) / Total`

Ejemplo: (1 + 0.5 + 0) / 3 = 50%

### Paso 5 — Generar informe + recomendaciones

```markdown
# Outcome Tracking Report — Release v1.2.0

Período: 2026-01-15 a 2026-02-15
Outcome Delivery Rate: 75%

## Features y Métricas

| Feature | Métrica | Baseline | Target | Actual 30d | Status | Delta |
|---------|---------|----------|--------|-----------|--------|-------|
| Login SSO | Tiempo login | 45s | 15s | 16s | ✅ | -63% |
| Dashboard | Adoption | 0% | 40% | 28% | 🟡 | +28% |
| Bug fix | Crash rate | 2.1% | <0.5% | 0.8% | 🟡 | -62% |

## Análisis

✅ Logros:
  - Login SSO superó expectativas (16s < 15s target)
  - Crash rate se redujo significativamente

🟡 En progreso:
  - Dashboard adoption va bien pero aún falta 12pp para target
  - Considerar campañas de onboarding adicionales

❌ Desviaciones (si las hay):
  - [Listar features que no cumplieron]

## Recomendaciones

1. **Para features en progreso**: {sugerencias basadas en datos}
2. **Para features completadas**: validar sostenibilidad a 60d
3. **Para el equipo**: aprender de qué salió bien (métrica login SSO)
4. **Para product**: refinar estimaciones en próximas releases

## Relación con OKRs

Si existe strategy.md:
  - Esta release contribuyó X% a OKR 1.2
  - Progreso acumulado post-release: Y%
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: outcome_tracking
release_id: "v1.2.0"
features_tracked: {n}
metrics_delivered: {n}
metrics_in_progress: {n}
metrics_missed: {n}
outcome_delivery_rate: "{percentage}%"
file_path: "output/outcomes/YYYYMMDD-outcome-track-{proyecto}-v{version}.md"
register_updated: {boolean}
```

---

## Restricciones

- **NUNCA** culpabilizar al equipo por outcomes no logrados — foco en aprender
- **NUNCA** cambiar baseline post-facto (invalida comparación)
- Métricas must-have: definir ANTES de release (no post-hoc)
- Si faltan datos, marcar como "No data available" — no especular
- Outcome Delivery Rate es indicador health, NO KPI de penalización
- Guardias: máximo 5 métricas por feature (evitar ruido); usar semanal tracking durante primeros 30 días
