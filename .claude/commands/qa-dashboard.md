---
name: qa-dashboard
description: Dashboard de calidad — cobertura, tests flaky, bugs, escape rate, trends
developer_type: all
agent: none
context_cost: medium
tier: extended
---

# /qa-dashboard

> 🦉 Savia te muestra la salud de la calidad en una sola vista.

---

## Cargar perfil de usuario

Grupo: **Quality & PRs** — cargar:

- `identity.md` — nombre, rol
- `workflow.md` — reviews_agent_code
- `tools.md` — ide, git_mode

---

## Subcomandos

- `/qa-dashboard` — dashboard completo del proyecto activo
- `/qa-dashboard {proyecto}` — dashboard de un proyecto específico
- `/qa-dashboard --trend` — incluir tendencia últimos 5 sprints

---

## Flujo

### Paso 1 — Recopilar métricas de calidad

| Métrica | Fuente |
|---|---|
| Cobertura por módulo | Test runner output / CI reports |
| Tests flaky | Tests que pasan/fallan intermitentemente en CI |
| Bugs abiertos | Azure DevOps work items tipo Bug |
| Bugs por severidad | Critical / High / Medium / Low distribution |
| Escape rate | Bugs encontrados en producción / total bugs sprint |
| Test execution time | Tiempo total de suite de tests |
| Tests pendientes | Tests marcados @skip / @pending |

### Paso 2 — Calcular Quality Score

```
Quality Score = 100
  - (100 - cobertura%) × 0.3
  - (flaky_count × 2)
  - (critical_bugs × 10)
  - (high_bugs × 5)
  - (escape_rate% × 20)
```

### Paso 3 — Mostrar dashboard

```
🦉 QA Dashboard — {proyecto} — {fecha}

📊 Quality Score: {N}/100 {🟢|🟡|🔴}

| Métrica | Valor | Trend | Estado |
|---|---|---|---|
| Cobertura | 78% | ↑ +3% | 🟢 |
| Tests flaky | 4 | → | 🟡 |
| Bugs abiertos | 12 | ↓ -3 | 🟢 |
| Bugs críticos | 0 | → | 🟢 |
| Escape rate | 8% | ↑ +2% | 🟡 |
| Test time | 4m 32s | → | 🟢 |
| Tests @skip | 7 | ↑ +2 | 🟡 |

⚠️ Alertas:
  - 4 tests flaky en módulo {X} — investigar
  - Escape rate subiendo — revisar QA pre-release
```

### Paso 4 — Desglose por módulo (si `--trend` o hay alertas)

Tabla de cobertura por módulo: módulo, % cobertura, tests, última ejecución.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: qa_dashboard
quality_score: 72
coverage: 78
flaky_tests: 4
open_bugs: 12
critical_bugs: 0
escape_rate: 8
test_time_seconds: 272
skipped_tests: 7
```

---

## Restricciones

- **NUNCA** inventar métricas — si no hay datos reales, indicar "Sin datos"
- Siempre mostrar tendencia respecto al sprint anterior si hay histórico
- Quality Score ≥ 75 = 🟢, 50-74 = 🟡, < 50 = 🔴
