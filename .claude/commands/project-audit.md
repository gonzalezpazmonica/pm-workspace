---
name: project-audit
description: >
  Phase 1 — Deep audit of a newly onboarded project: code quality,
  architecture, debt, security, CI/CD. Prioritized action report.
---

# Project Audit

**Argumentos:** $ARGUMENTS

> Uso: `/project-audit --project {p}` o `/project-audit --project {p} --deep`

Aplica siempre @.claude/rules/domain/command-ux-feedback.md

## 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /project-audit — Auditoría completa del proyecto
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

Mostrar ✅/❌: proyecto CLAUDE.md, acceso repo.

**Stack GitHub-only** (leer `CLAUDE.local.md` → `AZURE_DEVOPS_ENABLED = false`):
- Azure DevOps, pipelines Azure, WIQL → marcar N/A, NO intentar
- Usar: estructura repo, README, CI local, dependencias, código fuente

**Stack Azure DevOps:**
- Verificar: PAT, proyecto Azure DevOps, pipelines
- Si faltan opcionales → avisar N/A y continuar

Si falta CLAUDE.md del proyecto → modo interactivo: preguntar datos, crear, reintentar.

## 4. Delegar análisis a subagente

**OBLIGATORIO**: El análisis pesado se ejecuta en un subagente (`Task`) para proteger el contexto de la conversación principal.

Lanzar subagente con este prompt:

```
Analiza el proyecto {nombre} ubicado en projects/{nombre}/.
Lee su CLAUDE.md para entender el contexto.
Evalúa estas 8 dimensiones (peso entre paréntesis):
1. Calidad de código (15%): code smells, duplicación, complejidad
2. Cobertura de tests (15%): % cobertura, tests rotos, ratio test/code
3. Arquitectura (15%): acoplamiento, cohesión, patrones
4. Deuda técnica (10%): debt ratio, items críticos
5. Seguridad (15%): CVEs, dependencias EOL, secrets expuestos
6. Documentación (10%): README, ADRs, API docs
7. Madurez CI/CD (10%): pipelines, envs, deploy frequency
8. Salud del equipo (10%): bus factor, contributors

Dimensiones sin datos → "N/A" (no penalizan).
Clasificar hallazgos: 🔴 Crítico | 🟡 Mejorable | 🟢 Correcto
Score global X.X/10.

Guardar informe completo en: output/audits/YYYYMMDD-audit-{nombre}.md
Formato: resumen ejecutivo, scores por dimensión, hallazgos por tier,
plan de acción priorizado con esfuerzo estimado.
```

Mientras el subagente trabaja, mostrar progreso:
```
📋 Paso 1/1 — Análisis delegado a subagente (puede tardar ~2 min)...
```

## 5. Mostrar resumen en chat

Cuando el subagente termine, mostrar en chat SOLO el resumen (NO el informe completo):

```
📊 Score global: X.X/10
   Calidad código   ██████░░  6/10
   Tests            ████░░░░  4/10
   Arquitectura     ████████  8/10
   ...
🔴 Críticos: N hallazgos
🟡 Mejorables: N hallazgos
🟢 Correctos: N hallazgos
```

## 6. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /project-audit — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Informe: output/audits/YYYYMMDD-audit-{proyecto}.md
📊 Score global: X.X/10 | 🔴 N | 🟡 N | 🟢 N
💡 Siguiente: /project-release-plan --project {proyecto}
```

## Integración

- `/project-release-plan` → Phase 2, usa audit como input
- `/debt-track` → importa hallazgos de deuda
- `/risk-log` → alimenta registro desde hallazgos críticos

## Restricciones

- Solo lectura — no modifica código ni Azure DevOps
- Score orientativo, no sustituye juicio del equipo
- **NO ejecutar análisis en el contexto principal** — SIEMPRE subagente
