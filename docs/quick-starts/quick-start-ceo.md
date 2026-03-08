# Quick Start — CEO / CTO

> 🦉 Hola. Soy Savia. Para ti filtro solo lo que requiere decisión de dirección: estado del portfolio, métricas DORA, gobernanza IA y alertas que no pueden esperar. Sin ruido, solo señal.

---

## Primeros 10 minutos

```
/portfolio-overview --deps
```
Vista bird's-eye de todos los proyectos: estado, dependencias entre equipos y semáforo de riesgo.

```
/ceo-alerts
```
Solo las alertas que requieren tu decisión: sprints en riesgo, presupuestos excedidos, incidentes abiertos.

```
/kpi-dora
```
Métricas DORA del equipo: deployment frequency, lead time, change failure rate, time to restore.

---

## Tu día a día

**Lunes** — `/portfolio-overview` para la foto semanal. `/ceo-alerts` para lo urgente.

**Quincenal** — `/ceo-report --format pptx` genera la presentación de dirección con semáforo, métricas y recomendaciones.

**Mensual** — `/org-metrics --trend 6` para tendencias organizativas. `/ai-exposure-audit` para entender el impacto de la IA en los roles del equipo.

**Trimestral** — `/governance-report` consolida el estado de compliance. `/okr-track --trend` muestra el progreso estratégico.

---

## Cómo hablarme

| Tú dices... | Yo ejecuto... |
|---|---|
| "¿Cómo van los proyectos?" | `/portfolio-overview` |
| "¿Qué necesita mi atención?" | `/ceo-alerts` |
| "Dame el informe para el board" | `/ceo-report --format pptx` |
| "¿Cómo estamos en DORA?" | `/kpi-dora` |
| "¿Qué riesgo tiene la IA en el equipo?" | `/ai-exposure-audit` |
| "¿Cumplimos con gobernanza?" | `/governance-report` |

---

## Dónde están tus ficheros

```
output/
├── reports/
│   ├── ceo-report-*.pptx   ← informes de dirección
│   ├── portfolio-*.md       ← vistas de portfolio
│   └── governance-*.md      ← informes de compliance
└── alerts/                  ← histórico de alertas

.claude/commands/
├── ceo-*.md                 ← report, alerts
├── portfolio-*.md           ← overview, deps
├── governance-*.md          ← audit, report, certify
└── ai-*.md                  ← exposure audit, model cards
```

---

## Cómo se conecta tu trabajo

Todo lo que ves en `/ceo-report` viene de abajo: las horas del equipo (imputación) → costes por proyecto (cost-management) → márgenes. La velocity del sprint → forecast de entrega. Los tests del QA → change failure rate (DORA). Los ADRs del Tech Lead → trazabilidad de decisiones. Las alertas de burnout del PM → wellbeing. Tu vista es la agregación de todo el trabajo del equipo, filtrada para que solo veas lo que necesitas decidir.

El `/ai-exposure-audit` usa datos de O*NET para calcular cuánto de cada rol es automatizable con IA. Esto alimenta los reskilling plans y el workforce forecasting — decisiones estratégicas de dirección.

---

---

## Desde el móvil

Con Savia Mobile puedes consultar `/portfolio-overview`, `/ceo-alerts` y `/kpi-dora` desde tu Android. La app conecta al Bridge HTTPS y entrega respuestas en streaming — ideal para antes de un comité o mientras viajas. Setup: `projects/savia-mobile-android/docs/BRIDGE-GUIDE.md`

---

## Siguientes pasos

- [AI Augmentation por sector](../ai-augmentation-opportunities-es.md)
- [Gobernanza IA](../readme/10-kpis-reglas.md)
- [Flujo de datos](../data-flow-guide-es.md)
- [Guías por escenario](../guides/README.md)
