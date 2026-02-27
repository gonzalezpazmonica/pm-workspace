---
name: testplan-results
description: >
  Resultados detallados de ejecución de tests en Azure DevOps.
  Análisis de fallos, tendencias y recomendaciones.
---

# TestPlan Results

**Argumentos:** $ARGUMENTS

> Uso: `/testplan:results --project {p} --run {id}` o `--plan {id}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--run {id}` — ID del test run específico
- `--plan {id}` — Resultados del último run de un plan
- `--suite {id}` — Resultados de una suite específica
- `--status {passed|failed|blocked}` — Filtrar por resultado
- `--last {n}` — Últimos n runs (para análisis de tendencia)

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. Azure DevOps Test Plans con runs ejecutados

## Pasos de ejecución

### 1. Obtener resultados
- MCP: `get_test_results` → resultados del run/plan indicado
- Si `--last {n}` → obtener últimos n runs para tendencia

### 2. Analizar fallos

Para cada test fallido:
- Nombre del test case y suite
- Mensaje de error / stack trace (si disponible)
- Historial: ¿es un flaky test? ¿fallo nuevo o recurrente?
- PBI asociado (si linked)

### 3. Presentar resultados

```
## Test Results — {proyecto} — Run #{id}
Fecha: YYYY-MM-DD | Duración: 12m 34s | Ejecutor: Pedro López

### Resumen
Total: 47 | ✅ 30 (64%) | ❌ 7 (15%) | ⏸️ 3 (6%) | ⬜ 7 (15%)

### Fallos detallados
| # | Test Case | Suite | Error | Recurrente |
|---|---|---|---|---|
| 1 | TC-045 Payment validation | Payments | AssertionError: expected 200, got 500 | 🔴 3 runs |
| 2 | TC-048 Refund flow | Payments | Timeout after 30s | 🟡 Nuevo |
| 3 | TC-012 Token refresh | Auth | NullReferenceException | 🔴 5 runs |

### Tests bloqueados
| Test Case | Razón | Dependencia |
|---|---|---|
| TC-050 Payment report | Entorno PRE caído | Infra |

### Tendencia (últimos 5 runs)
Run #105: 64% passed
Run #104: 68% passed
Run #103: 55% passed ← regresión
Run #102: 72% passed
Run #101: 70% passed
Tendencia: 📉 bajando (-6% vs media)

### Recomendaciones
1. TC-012 Token refresh: fallo recurrente (5 runs) → crear Bug PBI
2. TC-045 Payment validation: fallo recurrente (3 runs) → investigar
3. Suite Payments: 5/22 fallan → bloquea release de PBI #1235
```

## Integración

- `/testplan:status` → vista general de planes y suites
- `/sentry:bugs` → correlacionar fallos de tests con errores en producción
- `/sprint:review` → incluir resultados en sprint review
- `/debt:track` → tests flaky como deuda técnica

## Restricciones

- Solo lectura — no ejecuta ni modifica test runs
- Stack traces pueden no estar disponibles para tests manuales
- Tendencia requiere al menos 3 runs anteriores
