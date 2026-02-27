---
name: project-audit
description: >
  Phase 1 — Deep audit of a newly onboarded project: code quality,
  architecture, debt, security, CI/CD. Prioritized action report.
---

# Project Audit

**Argumentos:** $ARGUMENTS

> Uso: `/project:audit --project {p}` o `/project:audit --project {p} --deep`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--deep` — Análisis profundo incluyendo código fuente y dependencias
- `--focus {area}` — Foco en área específica: code, tests, cicd, debt, security, docs
- `--compare {fecha}` — Comparar con audit anterior (evolución)
- `--output {format}` — Formato: `md` (defecto), `xlsx`, `pptx`

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. Acceso al repositorio (GitHub o Azure Repos)
3. Azure DevOps (backlog, pipelines) si está configurado

## Pasos de ejecución

### 1. Recopilar datos de todas las fuentes

Ejecutar internamente (según disponibilidad):
- `/pipeline:status` → madurez CI/CD, frecuencia de deploy, tasa de éxito
- `/debt:track` → deuda técnica existente, ratio, tendencia
- `/kpi:dora` → métricas DORA (si hay datos de pipeline)
- `/sentry:health` → tasa de errores, crash rate (si Sentry configurado)
- `/legacy:assess` → scores de complejidad (si es proyecto legacy)
- Repo analysis → LOC, tests, cobertura, dependencias

### 2. Evaluar 8 dimensiones

| Dimensión | Peso | Indicadores clave |
|---|---|---|
| Calidad de código | 15% | Code smells, duplicación, complejidad |
| Cobertura de tests | 15% | % cobertura, tests rotos, ratio test/code |
| Arquitectura | 15% | Acoplamiento, cohesión, patrones |
| Deuda técnica | 10% | Debt ratio, items críticos abiertos |
| Seguridad | 15% | CVEs, dependencias EOL, secrets expuestos |
| Documentación | 10% | README, ADRs, API docs, comments |
| Madurez CI/CD | 10% | Pipelines, envs, deploy frequency |
| Salud del equipo | 10% | Bus factor, contributors, workload |

### 3. Clasificar hallazgos en 3 tiers

**🔴 Crítico (must fix)** — Riesgo inmediato: CVEs, secrets, datos sin proteger, 0% tests en módulos críticos.

**🟡 Mejorable (should fix)** — Calidad comprometida: baja cobertura, deuda técnica alta, documentación pobre, CI/CD incompleto.

**🟢 Correcto (keep)** — Aspectos saludables que mantener o reforzar.

### 4. Generar informe

```
## Project Audit — {proyecto}
Fecha: YYYY-MM-DD | Score global: 6.2/10

### Resumen ejecutivo
{1-3 líneas con conclusión principal}

### Scores por dimensión
Código:      ██████░░░░ 6/10
Tests:       ████░░░░░░ 4/10
Arquitectura:███████░░░ 7/10
Deuda:       █████░░░░░ 5/10
Seguridad:   ████████░░ 8/10
Docs:        ███░░░░░░░ 3/10
CI/CD:       ██████░░░░ 6/10
Equipo:      ████████░░ 8/10

### 🔴 Crítico (3 items)
1. [SEC] 2 CVEs críticos en dependencia auth-lib v2.1
2. [TEST] 0% cobertura en módulo de pagos
3. [SEC] API key hardcodeada en config.json

### 🟡 Mejorable (5 items)
1. [DEBT] 23% debt ratio (objetivo <20%)
2. [DOCS] Sin documentación de API
...

### 🟢 Correcto (4 items)
1. [ARCH] Clean Architecture bien implementada
...

### Plan de acción priorizado
| # | Tier | Área | Acción | Esfuerzo | Sprint sugerido |
|---|---|---|---|---|---|
| 1 | 🔴 | SEC | Actualizar auth-lib a v3.0 | S | Sprint actual |
| 2 | 🔴 | TEST | Añadir tests módulo pagos | L | Sprint actual |
...
```

### 5. Guardar
- `output/audits/YYYYMMDD-audit-{proyecto}.md`

## Integración

- `/project:release-plan` → (Phase 2) usa audit como input principal
- `/legacy:assess` → fuente de datos para proyectos legacy
- `/debt:track` → importa hallazgos de deuda del audit
- `/risk:log` → alimenta registro de riesgos desde hallazgos críticos

## Restricciones

- Solo lectura — no modifica código ni Azure DevOps
- Score es orientativo, no sustituye el juicio del equipo
- Dimensiones sin datos se marcan "N/A" (no penalizan)
