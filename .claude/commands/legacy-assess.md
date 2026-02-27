---
name: legacy-assess
description: >
  Evaluación de aplicaciones legacy: complejidad, coste de mantenimiento,
  rating de riesgo y roadmap de modernización (strangler fig pattern).
---

# Legacy Assess

**Argumentos:** $ARGUMENTS

> Uso: `/legacy-assess --project {p}` o `/legacy-assess --project {p} --deep`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--repo {url}` — URL del repositorio a analizar (si no está en el proyecto)
- `--deep` — Análisis profundo: incluye métricas de código y dependencias
- `--compare` — Comparar con assessment anterior (evolución)
- `--output {format}` — Formato de salida: `md` (defecto), `xlsx`, `pptx`

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `.claude/skills/azure-devops-queries/SKILL.md` — Queries si hay work items
3. Acceso al repositorio del proyecto (Git clone o Azure Repos)

## Delegación a subagente

**OBLIGATORIO**: Todo el análisis (recopilar datos, calcular scores, generar roadmap) se ejecuta en un subagente (`Task`) para proteger el contexto. Mostrar: `📋 Paso 1/1 — Análisis delegado a subagente (puede tardar ~2 min)...`

El subagente ejecuta los pasos 1-5 abajo y guarda el informe en `output/assessments/`. El contexto principal solo recibe el resumen (score global + hallazgos críticos).

## Pasos de ejecución (dentro del subagente)

### 1. Recopilar datos
- **Código fuente**: LOC, lenguajes, edad del repo, frecuencia de commits
- **Dependencias**: paquetes obsoletos, CVEs conocidos, frameworks EOL
- **Tests**: cobertura, tests rotos, ratio test/código
- **CI/CD**: pipelines existentes (`/pipeline-status`), frecuencia de deploy
- **Deuda técnica**: si existe `debt-register.md`, incorporar datos
- **Errores**: si Sentry configurado (`/sentry-health`), crash rate

### 2. Calcular scores (1-10)

| Dimensión | Peso | Fuente |
|---|---|---|
| Complejidad del código | 20% | LOC, ciclomática, acoplamiento |
| Coste de mantenimiento | 20% | Bugs/mes, tiempo medio de fix |
| Riesgo técnico | 20% | Dependencias EOL, CVEs, sin tests |
| Calidad de documentación | 15% | README, ADRs, comments ratio |
| Madurez CI/CD | 15% | Pipelines, envs, deploy frequency |
| Conocimiento del equipo | 10% | Bus factor, contributors activos |

**Score global** = media ponderada → clasificación:
- 8-10: Saludable — mantenimiento normal
- 5-7: Atención requerida — plan de mejora recomendado
- 1-4: Crítico — modernización urgente

### 3. Generar roadmap de modernización

Si score < 7, proponer **strangler fig pattern**:
1. Identificar módulos más críticos (alto riesgo + alto acoplamiento)
2. Proponer orden de migración: módulos independientes primero
3. Para cada módulo: estrategia (rewrite, refactor, wrap, retire)
4. Estimar esfuerzo por módulo (T-shirt sizing: S/M/L/XL)
5. Generar timeline con dependencias entre módulos

### 4. Presentar informe

```
## Legacy Assessment — {proyecto}
Fecha: YYYY-MM-DD | Score global: 4.2/10 (Crítico)

### Scores por dimensión
Complejidad:    ██████░░░░ 6/10
Mantenimiento:  ███░░░░░░░ 3/10
Riesgo técnico: ████░░░░░░ 4/10
Documentación:  ██░░░░░░░░ 2/10
CI/CD:          █████░░░░░ 5/10
Conocimiento:   ████░░░░░░ 4/10

### Hallazgos críticos
- 23 dependencias obsoletas (4 con CVEs conocidos)
- 0% test coverage en módulo de pagos
- No hay pipeline de deploy a PRO (manual)
- Bus factor = 1 (solo un contributor activo en 6 meses)

### Roadmap de modernización (strangler fig)
| Fase | Módulos | Estrategia | Esfuerzo | Sprints |
|---|---|---|---|---|
| 1 | Auth, Config | Refactor + tests | M | 2 |
| 2 | Pagos | Rewrite (nuevo servicio) | XL | 4 |
| 3 | Reporting | Wrap (API facade) | L | 3 |
| 4 | Core | Refactor incremental | XL | 6 |
```

### 5. Guardar informe
- `output/assessments/YYYYMMDD-legacy-{proyecto}.md`
- Si `--output xlsx` → generar Excel con detalle

## Integración

- `/project-audit` → usa legacy-assess como fuente para proyectos legacy
- `/project-release-plan` → incorpora roadmap de modernización como input
- `/debt-track` → importa hallazgos como items de deuda técnica
- `/evaluate-repo` → complementario (evaluate-repo = seguridad, legacy-assess = salud global)

## Restricciones

- No modifica código ni crea branches — solo analiza y reporta
- El score es orientativo, no sustituye el juicio del equipo
- Acceso al repo necesario para análisis profundo (`--deep`)
- **NO ejecutar análisis en el contexto principal** — SIEMPRE subagente
