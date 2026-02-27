---
name: project-assign
description: >
  Phase 3 — Distribute release plan work across the team by profiles,
  skills, seniority, and capacity. Generates assignment matrix.
---

# Project Assign

**Argumentos:** $ARGUMENTS

> Uso: `/project-assign --project {p}` o con `--release-plan {file}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--release-plan {file}` — Fichero de release plan (defecto: último generado)
- `--release {n}` — Asignar solo una release específica
- `--sprint {nombre}` — Asignar solo para un sprint específico
- `--rebalance` — Rebalancear asignaciones existentes
- `--dry-run` — Solo mostrar propuesta, no asignar en Azure DevOps

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `projects/{proyecto}/equipo.md` — Perfiles del equipo
3. `output/plans/` — Último release plan (o `--release-plan`)
4. `.claude/skills/pbi-decomposition/SKILL.md` — Scoring de asignación

## Pasos de ejecución

### 1. Cargar datos del equipo
- Leer `equipo.md` → nombre, rol, skills, seniority, disponibilidad
- Obtener capacity actual → `/report-capacity`
- Obtener carga actual → `/team-workload`
- Calcular horas disponibles por persona y sprint

### 2. Cargar trabajo a asignar
- Leer release plan → PBIs agrupados por release y sprint
- Para PBIs sin descomponer → invocar `/pbi-decompose` primero
- Obtener tasks con estimaciones (SP u horas)

### 3. Algoritmo de asignación

Para cada task, calcular score por persona:
```
Score = (skill_match × 0.4) + (capacity_available × 0.3)
      + (seniority_fit × 0.2) + (context_bonus × 0.1)
```

Donde:
- **skill_match**: % de coincidencia entre skills de la task y del dev
- **capacity_available**: horas libres / horas de la task
- **seniority_fit**: match entre complejidad y nivel (no asignar L a junior)
- **context_bonus**: ya trabajó en módulo relacionado

Restricciones:
- Ninguna persona supera 100% de su capacity
- Tasks críticas (🔴) asignadas a senior/mid mínimo
- Bus factor ≥ 2 por módulo (no todo a una persona)

### 4. Presentar matriz de asignación

```
## Assignment Matrix — {proyecto} — Release {n}

### Carga por persona
| Persona | Rol | Capacity | Asignado | % Uso | Alerta |
|---|---|---|---|---|---|
| Ana García | Senior Dev | 64h | 58h | 91% | — |
| Pedro López | Mid Dev | 64h | 52h | 81% | — |
| María Ruiz | Junior Dev | 64h | 40h | 63% | — |
| Carlos Sanz | QA | 64h | 68h | 106% | ⚠️ Sobrecarga |

### Asignaciones por PBI
| PBI | Task | Asignado | Score | Skill match |
|---|---|---|---|---|
| #1234 Fix Auth | T1: Update lib | Ana | 0.92 | 95% |
| #1234 Fix Auth | T2: Tests | Pedro | 0.85 | 80% |
| #1235 Tests Pagos | T1: Unit tests | María | 0.78 | 70% |

### Alertas
- ⚠️ Carlos Sanz sobrecargado en Sprint 3 → sugerir redistribuir
- ℹ️ Módulo "Pagos" asignado solo a María → bus factor = 1
```

### 5. Aplicar asignaciones
- Si `--dry-run` → solo mostrar propuesta
- Si no → **confirmar con PM** → asignar tasks en Azure DevOps

## Integración

- `/project-release-plan` → (Phase 2) provee el trabajo a asignar
- `/project-roadmap` → (Phase 4) visualiza asignaciones en timeline
- `/pbi-decompose` → descompone PBIs antes de asignar tasks
- `/team-workload` → datos de carga actual
- `/report-capacity` → datos de capacity

## Restricciones

- NUNCA asignar sin confirmación del PM (regla 7)
- `equipo.md` debe existir con perfiles del equipo
- Si no hay release plan, trabaja sobre backlog del sprint actual
