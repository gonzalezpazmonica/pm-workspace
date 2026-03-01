---
name: ceo-report
description: Informe ejecutivo multi-proyecto para dirección — portfolio, riesgo, equipo, delivery
developer_type: all
agent: task
context_cost: high
---

# /ceo-report

> 🦉 Savia prepara el informe que tu comité de dirección necesita.

---

## Cargar perfil de usuario

Grupo: **Reporting** — cargar:

- `identity.md` — nombre, empresa (headers)
- `preferences.md` — language, detail_level, report_format, date_format
- `projects.md` — qué proyectos incluir
- `tone.md` — formality (narrativa ejecutiva)

---

## Subcomandos

- `/ceo-report` — informe completo multi-proyecto
- `/ceo-report {proyecto}` — informe de un solo proyecto
- `/ceo-report --format {md|pdf|pptx}` — elegir formato de salida

---

## Flujo

### Paso 1 — Recopilar datos de cada proyecto

Para cada proyecto en `projects.md`:

1. Sprint actual: velocity, burndown, % completado
2. Equipo: utilización, alertas de sobrecarga
3. Deuda técnica: tendencia últimos 3 sprints
4. Riesgos: items del risk-register con exposure > media
5. Delivery: lead time, deployment frequency (DORA)

### Paso 2 — Calcular indicadores de portfolio

| Indicador | Fórmula |
|---|---|
| Portfolio Health | Media ponderada de health scores por proyecto |
| Risk Exposure | Suma de (probabilidad × impacto) de riesgos activos |
| Team Utilization | Capacidad usada / capacidad total × 100 |
| Delivery Velocity | Trend de velocity últimos 3 sprints (↑/→/↓) |
| Budget Burn Rate | Si disponible: gasto acumulado vs. planificado |

### Paso 3 — Generar semáforo por proyecto

| Color | Criterio |
|---|---|
| 🟢 | Health ≥ 75, sin riesgos críticos, velocity estable/↑ |
| 🟡 | Health 50-74, o riesgos medios, o velocity ↓ 1 sprint |
| 🔴 | Health < 50, o riesgos críticos, o velocity ↓ 2+ sprints |

### Paso 4 — Redactar informe

Estructura del informe ejecutivo:

1. **Resumen ejecutivo** — 3-5 líneas con lo esencial
2. **Semáforo de portfolio** — tabla proyecto × estado × razón
3. **Métricas clave** — los 5 indicadores del Paso 2
4. **Riesgos y decisiones pendientes** — items que requieren acción de dirección
5. **Próximos hitos** — milestones de los próximos 30 días
6. **Recomendaciones de Savia** — máximo 3 acciones priorizadas

### Paso 5 — Exportar

Guardar en `output/reports/ceo-report-{fecha}.{formato}`.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: ceo_report
projects_analyzed: 3
portfolio_health: 72
risk_exposure: medium
team_utilization: 87
delivery_trend: stable
output_file: output/reports/ceo-report-2026-03-01.md
```

---

## Restricciones

- **NUNCA** inventar datos — si no hay métricas reales, indicar "Sin datos"
- **NUNCA** minimizar riesgos — el CEO necesita la verdad
- Lenguaje ejecutivo: sin jerga técnica, sin detalles de implementación
- Máximo 2 páginas en formato PDF/PPTX
