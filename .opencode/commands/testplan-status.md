---
name: testplan-status
description: >
  Estado de Test Plans en Azure DevOps: planes activos,
  suites, casos de test, ejecución y cobertura.
---

# TestPlan Status

**Argumentos:** $ARGUMENTS

> Uso: `/testplan-status --project {p}` o `/testplan-status --project {p} --plan {id}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--plan {id|nombre}` — Test Plan específico (defecto: todos los activos)
- `--suite {id}` — Suite específica dentro del plan
- `--sprint {nombre}` — Filtrar por sprint asociado
- `--assigned {persona}` — Filtrar por tester asignado

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. Azure DevOps Test Plans configurados en el proyecto

## Pasos de ejecución

### 1. Obtener datos
- MCP: `get_test_plans` → listar planes de test del proyecto
- Para cada plan activo: MCP: `get_test_suites` → suites
- Para cada suite: obtener test cases y estados

### 2. Calcular métricas

- **Total test cases** por plan/suite
- **Ejecución**: % passed, failed, blocked, not run
- **Cobertura**: PBIs con tests asociados vs PBIs sin tests
- **Tendencia**: comparar con sprint anterior si hay datos

### 3. Presentar dashboard

```
## Test Plans — {proyecto}

### Plan activo: "Sprint 2026-04 Tests"
| Suite | Total | ✅ Passed | ❌ Failed | ⏸️ Blocked | ⬜ Not Run |
|---|---|---|---|---|---|
| Auth Module | 15 | 12 | 2 | 0 | 1 |
| Payments | 22 | 8 | 5 | 3 | 6 |
| Dashboard | 10 | 10 | 0 | 0 | 0 |
| **Total** | **47** | **30 (64%)** | **7 (15%)** | **3 (6%)** | **7 (15%)** |

### Cobertura por PBI
| PBI | Tests | Ejecución | Estado |
|---|---|---|---|
| #1234 Auth SSO | 8 | 6/8 passed | 🟡 Parcial |
| #1235 Payments | 12 | 3/12 passed | 🔴 Crítico |
| #1236 Dashboard | 10 | 10/10 passed | 🟢 Completo |
| #1237 Reports | 0 | — | ⚠️ Sin tests |

### Alertas
- ⚠️ PBI #1237 sin tests asociados
- 🔴 Suite Payments: 5 failures en último run
- ℹ️ 7 tests pendientes de ejecutar
```

## Integración

- `/testplan-results` → detalle de resultados de ejecución
- `/kpi-dashboard` → incluye cobertura de tests como KPI
- `/sprint-review` → resumen de test status para review
- `/project-audit` → evalúa madurez de testing

## Restricciones

- Solo lectura — no crea ni modifica test plans
- Requiere Azure DevOps Test Plans habilitado en el proyecto
- MCP tools: `get_test_plans`, `get_test_suites`, `get_test_results`
