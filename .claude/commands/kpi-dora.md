---
name: kpi-dora
description: >
  Dashboard de métricas DORA: deployment frequency, lead time for changes,
  change failure rate, MTTR y reliability.
---

# KPI DORA

**Argumentos:** $ARGUMENTS

> Uso: `/kpi:dora --project {p}` o `/kpi:dora --project {p} --sprints 10`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--sprints {n}` — Período de análisis en sprints (defecto: 5)
- `--pipeline {nombre}` — Pipeline específica (opcional)
- `--compare {proyecto2}` — Comparar con otro proyecto
- `--export` — Guardar informe en `output/dora/`

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `.claude/skills/azure-pipelines/SKILL.md` — MCP tools de pipelines

## Métricas DORA calculadas

| Métrica | Fuente | Cálculo |
|---|---|---|
| Deployment Frequency | MCP `get_builds` | Deploys a PRO por semana/mes |
| Lead Time for Changes | MCP `get_builds` + repos | Tiempo primer commit → deploy PRO |
| Change Failure Rate | MCP `get_builds` | Builds fallidas en PRO / total deploys PRO |
| MTTR | MCP `get_builds` | Tiempo medio entre fallo y fix en PRO |
| Reliability | Sentry + pipelines | Uptime estimado desde error rate y deploys |

## Pasos de ejecución

1. **Obtener datos de pipelines** — MCP `get_builds` del período
2. **Filtrar deploys a producción** — builds con stage PRO/Production
3. **Calcular cada métrica** según tabla anterior
4. **Clasificar rendimiento** según benchmarks DORA 2025:

| Métrica | Elite | High | Medium | Low |
|---|---|---|---|---|
| Deploy Frequency | On-demand (multi/día) | 1/semana-1/mes | 1/mes-6/mes | < 1/6m |
| Lead Time | < 1 día | 1 día - 1 semana | 1 sem - 1 mes | > 1 mes |
| Change Failure Rate | < 5% | 5-10% | 10-15% | > 15% |
| MTTR | < 1 hora | < 1 día | < 1 semana | > 1 semana |

5. **Presentar dashboard:**

```
## DORA Metrics — {proyecto} — Últimos {n} sprints

| Métrica | Valor | Clasificación | Tendencia |
|---|---|---|---|
| Deploy Frequency | 3.2/semana | Elite | 📈 +15% |
| Lead Time | 2.1 días | High | 📉 -0.5d |
| Change Failure Rate | 8% | High | → estable |
| MTTR | 45 min | Elite | 📉 -12min |

Clasificación global: HIGH PERFORMER

Recomendación: Reducir lead time automatizando merge → deploy
```

6. **Si `--export`** → guardar en `output/dora/YYYYMMDD-dora-{proyecto}.md`

## Integración

- `/kpi:dashboard` → incluye resumen DORA
- `/pipeline:status` → datos fuente
- `/project:audit` → usa DORA para evaluar madurez CI/CD
- `/report:executive` → incluye DORA en informe directivo

## Restricciones

- Requiere historial de pipelines (mínimo 1 sprint con deploys)
- Si no hay pipeline de PRO → informar y calcular solo sobre DEV/PRE
- Benchmarks DORA 2025 como referencia, no como objetivo rígido
