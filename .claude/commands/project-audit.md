---
name: project-audit
description: >
  Phase 1 — Deep audit of a newly onboarded project: code quality,
  architecture, debt, security, CI/CD. Prioritized action report.
---

# Project Audit

**Argumentos:** $ARGUMENTS

> Uso: `/project:audit --project {p}` o `/project:audit --project {p} --deep`

Aplica siempre @.claude/rules/command-ux-feedback.md

## 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /project:audit — Auditoría completa del proyecto
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Parámetros

- `--project {nombre}` — Proyecto (obligatorio)
- `--deep` — Análisis profundo con código fuente y dependencias
- `--focus {area}` — Foco: code, tests, cicd, debt, security, docs
- `--compare {fecha}` — Comparar con audit anterior
- `--output {format}` — md (defecto), xlsx, pptx

Si falta `--project` → listar proyectos disponibles con sugerencia de uso.

## 3. Verificar prerequisitos

Mostrar ✅/❌: proyecto CLAUDE.md, acceso repo, Azure DevOps, pipelines.
Si falta CLAUDE.md → modo interactivo: preguntar datos, crear, reintentar.
Si faltan opcionales (AzDO, pipelines, Sentry) → avisar N/A y continuar.

## 4. Recopilar datos (con progreso)

```
📋 Paso 1/5 — Analizando estructura del repositorio...
📋 Paso 2/5 — Evaluando calidad de código y tests...
📋 Paso 3/5 — Revisando seguridad y dependencias...
📋 Paso 4/5 — Analizando CI/CD y métricas...
📋 Paso 5/5 — Generando informe y scoring...
```

Internamente usar (según disponibilidad): `/debt:track`, `/kpi:dora`, `/pipeline:status`, `/sentry:health`, `/security:alerts`, `/legacy:assess`.

## 5. Evaluar 8 dimensiones

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

Dimensiones sin datos → "N/A" (no penalizan).

## 6. Clasificar y mostrar informe

**🔴 Crítico** — Riesgo inmediato | **🟡 Mejorable** — Calidad comprometida | **🟢 Correcto**

Mostrar SIEMPRE en pantalla: resumen ejecutivo, barras de score por dimensión, hallazgos por tier, plan de acción priorizado con esfuerzo y sprint sugerido.

## 7. Guardar y banner de fin

Guardar: `output/audits/YYYYMMDD-audit-{proyecto}.md`

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /project:audit — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Informe: output/audits/YYYYMMDD-audit-{proyecto}.md
📊 Score global: X.X/10 | 🔴 N | 🟡 N | 🟢 N
💡 Siguiente paso: /project:release-plan --project {proyecto}
```

## Integración

- `/project:release-plan` → Phase 2, usa audit como input
- `/debt:track` → importa hallazgos de deuda
- `/risk:log` → alimenta registro desde hallazgos críticos

## Restricciones

- Solo lectura — no modifica código ni Azure DevOps
- Score orientativo, no sustituye juicio del equipo
