---
name: project-release-plan
description: >
  Phase 2 — Generate prioritized release plan from audit + backlog.
  Respects dependencies, risk, and business value.
---

# Project Release Plan

**Argumentos:** $ARGUMENTS

> Uso: `/project-release-plan --project {p}` o con `--audit {file}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--audit {file}` — Fichero de audit previo (defecto: último generado)
- `--sprints {n}` — Horizonte de planificación en sprints (defecto: 6)
- `--strategy {greenfield|legacy|hybrid}` — Estrategia (auto-detecta si no se indica)
- `--output {format}` — Formato: `md` (defecto), `xlsx`

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `output/audits/` — Último audit del proyecto (o `--audit`)
3. `.claude/skills/azure-devops-queries/SKILL.md` — Backlog existente
4. `.claude/skills/pbi-decomposition/SKILL.md` — Scoring de PBIs

## Pasos de ejecución

### 1. Recopilar inputs
- **Audit report** → acciones priorizadas por tier (🔴🟡🟢)
- **Backlog existente** → PBIs en Azure DevOps (New + Active)
- **Dependencias** → `/dependency-map` si hay datos
- **Riesgos** → `/risk-log` si hay registro
- **Capacity del equipo** → `equipo.md` + `/report-capacity`

### 2. Agrupar en releases lógicas

Criterios de agrupación:
1. **Dependencias**: items dependientes van en la misma release o en orden
2. **Coherencia funcional**: features relacionadas juntas
3. **Riesgo**: items 🔴 en releases tempranas
4. **Business value**: items de mayor valor antes (MoSCoW si disponible)

Para proyectos **legacy** → aplicar strangler fig:
- Release 1: estabilizar (tests, CI/CD, security fixes)
- Release 2-N: migrar módulo por módulo (de menor a mayor acoplamiento)
- Release final: retirar código legacy

### 3. Definir cada release

Para cada release:
```
### Release {n}: {nombre descriptivo}
Objetivo: {1 línea}
Sprints estimados: {n}
Entry criteria: {condiciones para empezar}
Exit criteria: {definición de hecho}

PBIs incluidos:
| ID | Título | Tipo | SP | Dependencias |
|---|---|---|---|---|
| #1234 | Fix CVEs en auth | Bug | 5 | — |
| #1235 | Tests módulo pagos | Tech | 13 | — |
| #1236 | API v2 | Story | 21 | #1234 |

Riesgos: {riesgos asociados}
```

### 4. Generar plan consolidado

```
## Release Plan — {proyecto}
Fecha: YYYY-MM-DD | Horizonte: {n} sprints | Estrategia: {tipo}

### Timeline
Release 1 "Stabilize" — Sprint 1-2 (4 semanas)
Release 2 "Core Features" — Sprint 3-5 (6 semanas)
Release 3 "Polish & Launch" — Sprint 6 (2 semanas)

### Resumen
| Release | Sprints | PBIs | SP | Riesgo | Dependencias |
|---|---|---|---|---|---|
| R1: Stabilize | 1-2 | 8 | 34 | Alto | — |
| R2: Core | 3-5 | 12 | 55 | Medio | R1 |
| R3: Polish | 6 | 5 | 18 | Bajo | R2 |

### Dependencias entre releases
R1 → R2 → R3 (secuencial)
R2.3 (#1240) → R2.5 (#1242) (intra-release)

### Ruta crítica
R1/#1234 → R2/#1236 → R3/#1250 (estimado: 10 sprints)
```

### 5. Guardar
- `output/plans/YYYYMMDD-release-plan-{proyecto}.md`

## Integración

- `/project-audit` → (Phase 1) provee el input principal
- `/project-assign` → (Phase 3) distribuye trabajo del plan
- `/project-roadmap` → (Phase 4) visualiza el plan como timeline
- `/dependency-map` → mapa de dependencias entre PBIs
- `/pbi-decompose` → descomponer PBIs del plan en tasks

## Restricciones

- No crea work items — solo planifica y propone
- El PM revisa y aprueba antes de ejecutar
- Sin audit previo, genera plan solo desde backlog existente
