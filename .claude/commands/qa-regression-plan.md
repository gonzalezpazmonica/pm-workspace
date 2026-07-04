---
name: qa-regression-plan
description: Plan de regresión basado en ficheros cambiados — impacto de cambios y suites a ejecutar
developer_type: all
agent: task
context_cost: high
tier: extended
---

# /qa-regression-plan

> 🦉 Savia analiza qué ha cambiado y te dice qué tests necesitas ejecutar.

---

## Cargar perfil de usuario

Grupo: **Quality & PRs** — cargar:

- `identity.md` — nombre, rol
- `workflow.md` — reviews_agent_code
- `tools.md` — ide, git_mode

---

## Subcomandos

- `/qa-regression-plan` — analizar cambios del sprint actual
- `/qa-regression-plan {branch}` — analizar cambios de una rama
- `/qa-regression-plan --pr {id}` — analizar cambios de un PR

---

## Flujo

### Paso 1 — Identificar ficheros cambiados

Obtener diff de la fuente indicada (sprint, branch o PR).
Clasificar ficheros por tipo: producción, tests, config, docs.

### Paso 2 — Analizar impacto

Para cada fichero de producción cambiado:

1. Buscar tests existentes que lo cubren (import/require graph)
2. Buscar dependencias inversas (quién importa este módulo)
3. Clasificar impacto: directo (test cubre el fichero), indirecto (test cubre un consumidor), sin cobertura

### Paso 3 — Generar plan de regresión

```
🦉 Regression Plan — {fuente}

📊 Resumen:
  Ficheros cambiados: {N} producción, {N} tests, {N} config
  Impacto estimado: {low|medium|high|critical}

✅ Tests de regresión recomendados:
  1. [DIRECTO] {test-suite-A} — cubre {fichero-1, fichero-2}
  2. [DIRECTO] {test-suite-B} — cubre {fichero-3}
  3. [INDIRECTO] {test-suite-C} — consumidor de {fichero-1}

⚠️ Sin cobertura:
  - {fichero-4} — nuevo, sin tests aún
  - {fichero-5} — cambiado, 0 tests encontrados

💡 Recomendación:
  {sugerencia de tests a crear}
```

### Paso 4 — Estimar tiempo de ejecución

Si hay histórico de test execution, estimar tiempo total de las suites recomendadas.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: qa_regression_plan
files_changed: 12
impact: medium
direct_tests: 5
indirect_tests: 3
uncovered_files: 2
estimated_time_minutes: 8
```

---

## Restricciones

- **NUNCA** ejecutar tests automáticamente — solo planificar
- **NUNCA** omitir ficheros sin cobertura — siempre reportarlos
- Priorizar tests directos sobre indirectos
