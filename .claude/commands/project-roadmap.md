---
name: project-roadmap
description: >
  Phase 4 — Generate visual roadmap from release plan: timeline,
  milestones, dependencies. Mermaid gantt → Draw.io/Miro.
tier: core
---

# Project Roadmap

**Argumentos:** $ARGUMENTS

> Uso: `/project-roadmap --project {p}` o con `--release-plan {file}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--release-plan {file}` — Fichero de release plan (defecto: último)
- `--format {mermaid|drawio|miro}` — Formato de diagrama (defecto: mermaid)
- `--audience {tech|executive}` — Nivel de detalle
- `--include-assignments` — Incluir asignaciones por persona
- `--output {format}` — Texto: `md` (defecto), `pptx`

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `output/plans/` — Último release plan
3. `.opencode/skills/diagram-generation/SKILL.md` — Generación de diagramas
4. `docs/rules/domain/diagram-config.md` — Config Draw.io/Miro

## Pasos de ejecución

### 1. Cargar datos
- Release plan → releases, sprints, PBIs, dependencias
- Asignaciones → si `/project-assign` ya ejecutado
- Calendario → fechas de sprints, festivos

### 2. Generar diagrama Gantt (Mermaid)

```mermaid
gantt
    title Roadmap — {proyecto}
    dateFormat YYYY-MM-DD
    axisFormat %d/%m

    section Release 1: Stabilize
    Fix CVEs auth      :crit, r1t1, 2026-03-02, 5d
    Tests módulo pagos  :r1t2, 2026-03-02, 10d
    CI/CD pipeline      :r1t3, after r1t1, 5d

    section Release 2: Core Features
    API v2              :r2t1, after r1t3, 15d
    Dashboard métricas  :r2t2, after r1t2, 10d
    Notificaciones      :r2t3, after r2t1, 8d

    section Release 3: Polish
    UX refinement       :r3t1, after r2t3, 5d
    Performance tuning  :r3t2, after r2t2, 5d

    section Milestones
    MVP                 :milestone, m1, after r1t3, 0d
    Beta                :milestone, m2, after r2t3, 0d
    Launch              :milestone, m3, after r3t2, 0d
```

### 3. Adaptar por audiencia

**tech**: incluye PBIs, tasks, dependencias, asignaciones por persona
**executive**: solo releases, milestones, fechas clave, riesgos top

### 4. Publicar diagrama

- Si `--format mermaid` → incluir en markdown del roadmap
- Si `--format drawio` → usar `/diagram-generate` → exportar XML
- Si `--format miro` → usar `/diagram-generate` → publicar board

### 5. Generar resumen ejecutivo

```
## Roadmap — {proyecto}
Fecha: YYYY-MM-DD | Horizonte: {n} sprints ({m} semanas)

### Timeline visual
[Gantt diagram above]

### Milestones
| Milestone | Fecha | Releases | Estado |
|---|---|---|---|
| MVP | 2026-03-14 | R1 | 🔴 Pendiente |
| Beta | 2026-04-11 | R1+R2 | — |
| Launch | 2026-04-25 | R1+R2+R3 | — |

### Riesgos para el timeline
1. Dependencia de API Gateway (equipo Platform) → retraso +1 sprint
2. Capacity reducida en Sprint 4 (vacaciones Ana)

### Próximos pasos
1. Aprobar release plan
2. Iniciar Sprint 1 con scope de Release 1
3. Review de progreso en Sprint Review
```

### 6. Guardar
- Diagrama: `output/roadmaps/YYYYMMDD-roadmap-{proyecto}.mermaid`
- Resumen: `output/roadmaps/YYYYMMDD-roadmap-{proyecto}.md`
- Si `--output pptx` → usar `/report-executive` para presentación

## Integración

- `/project-release-plan` → (Phase 2) fuente de datos principal
- `/project-assign` → (Phase 3) asignaciones para vista tech
- `/project-kickoff` → (Phase 5) incluye roadmap en el kickoff
- `/diagram-generate` → publicar en Draw.io o Miro
- `/report-executive` → versión presentación del roadmap

## Restricciones

- Solo lectura — no crea work items ni modifica Azure DevOps
- Diagrama Mermaid es local; Draw.io/Miro requieren config previa
- Fechas son estimadas, basadas en velocity y capacity
