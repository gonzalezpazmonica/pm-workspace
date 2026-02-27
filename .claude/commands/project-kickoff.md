---
name: project-kickoff
description: >
  Phase 5 — Compile audit + plan + assignments + roadmap into kickoff
  report. Notify PM. Create Sprint 1 backlog in Azure DevOps.
---

# Project Kickoff

**Argumentos:** $ARGUMENTS

> Uso: `/project:kickoff --project {p}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--notify {canal}` — Canal de notificación: slack, email (defecto: solo local)
- `--create-sprint` — Crear Sprint 1 en Azure DevOps con scope de Release 1
- `--dry-run` — Solo mostrar resumen, sin crear nada ni notificar

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `output/audits/` — Último audit (Phase 1)
3. `output/plans/` — Último release plan (Phase 2)
4. `output/roadmaps/` — Último roadmap (Phase 4)
5. Resultados de `/project:assign` (Phase 3)

## Pasos de ejecución

### 1. Compilar resultados de las 4 fases

Verificar que existen outputs de:
- ✅ Phase 1: Audit → score global, hallazgos críticos
- ✅ Phase 2: Release Plan → releases, timeline, dependencias
- ✅ Phase 3: Assignments → matriz de asignación, alertas
- ✅ Phase 4: Roadmap → diagrama, milestones

Si falta alguna fase → avisar al PM y sugerir ejecutarla.

### 2. Generar Kickoff Report

```
## Project Kickoff — {proyecto}
Fecha: YYYY-MM-DD

### 1. Estado del proyecto
Score global: {n}/10 | Items críticos: {n} | Deuda técnica: {n}%
{1-2 líneas de resumen del audit}

### 2. Plan de releases
| Release | Objetivo | Sprints | SP | Risk |
|---|---|---|---|---|
| R1: Stabilize | Fix críticos + tests | 1-2 | 34 | Alto |
| R2: Core | Features principales | 3-5 | 55 | Medio |
| R3: Launch | Polish + deploy | 6 | 18 | Bajo |

### 3. Equipo y asignaciones
| Persona | Rol | Sprint 1 | Sprint 2 |
|---|---|---|---|
| Ana | Senior Dev | Auth fix, CI/CD | API v2 |
| Pedro | Mid Dev | Tests pagos | Dashboard |
| María | Junior Dev | Docs API | Notificaciones |

Alertas: {alertas de capacity o bus factor}

### 4. Roadmap
[Enlace o embed del diagrama Mermaid/Gantt]

Milestones: MVP ({fecha}), Beta ({fecha}), Launch ({fecha})

### 5. Próximos pasos
1. Sprint Planning del Sprint 1: {fecha}
2. Daily standup: cada día a las 09:15
3. Sprint Review R1: {fecha}

### 6. Riesgos top
| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| {riesgo 1} | Alta | Alto | {acción} |
```

### 3. Crear Sprint 1 (si `--create-sprint`)
- Crear iteration en Azure DevOps (nombre: Sprint YYYY-NN)
- Mover PBIs de Release 1 al sprint
- Asignar tasks según matriz de `/project:assign`
- ⚠️ **Confirmar con PM antes de crear**

### 4. Notificar (si `--notify`)
- **slack**: enviar resumen al canal del proyecto via `/notify:slack`
- **email**: generar email con kickoff report (no envía, solo genera)
- Incluir: score, releases, roadmap, próximos pasos

### 5. Guardar
- `output/kickoffs/YYYYMMDD-kickoff-{proyecto}.md`

## Integración

- `/project:audit` → Phase 1 input
- `/project:release-plan` → Phase 2 input
- `/project:assign` → Phase 3 input
- `/project:roadmap` → Phase 4 input
- `/notify:slack` → distribución del kickoff
- `/sprint:plan` → refinamiento del Sprint 1 post-kickoff

## Restricciones

- NUNCA crear sprint sin confirmación del PM
- Si faltan fases previas, sugiere completarlas primero
- Notificación requiere conector configurado
- El kickoff report es de uso interno, no público
