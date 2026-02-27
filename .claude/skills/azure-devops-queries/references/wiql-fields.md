# WIQL Fields — Referencia Completa

## Campos del Sistema

| Campo | Alias | Descripción |
|-------|-------|-------------|
| `System.Id` | ID | Identificador único del work item |
| `System.Title` | Title | Título del work item |
| `System.State` | State | Estado: New, Active, Resolved, Closed, Done |
| `System.WorkItemType` | WorkItemType | User Story, Task, Bug, PBI, Epic, Feature |
| `System.AssignedTo` | AssignedTo | Usuario asignado |
| `System.CreatedDate` | CreatedDate | Fecha de creación |
| `System.ChangedDate` | ChangedDate | Última fecha de modificación |
| `System.IterationPath` | IterationPath | Sprint/iteración (ej: Project\Sprints\Sprint 1) |
| `System.AreaPath` | AreaPath | Ruta de área |
| `System.TeamProject` | TeamProject | Nombre del proyecto |

## Campos de Scheduling (Horas)

| Campo | Alias | Descripción |
|-------|-------|-------------|
| `Microsoft.VSTS.Scheduling.StoryPoints` | StoryPoints | Puntos de historia (estimación) |
| `Microsoft.VSTS.Scheduling.OriginalEstimate` | OriginalEstimate | Estimación original en horas |
| `Microsoft.VSTS.Scheduling.RemainingWork` | RemainingWork | Horas restantes para completar |
| `Microsoft.VSTS.Scheduling.CompletedWork` | CompletedWork | Horas completadas/imputadas |

## Campos de Clasificación

| Campo | Alias | Descripción |
|-------|-------|-------------|
| `Microsoft.VSTS.Common.Priority` | Priority | Prioridad: 1 (crítica) a 4 (baja) |
| `Microsoft.VSTS.Common.Severity` | Severity | Severidad de bugs: 1 (crítica) a 4 (baja) |
| `Microsoft.VSTS.Common.Activity` | Activity | Tipo actividad: Development, Testing, Design, etc. |

## Operadores Comunes

- `UNDER` — Iteraciones anidadas (ej: `UNDER @CurrentIteration`)
- `IN` — Múltiples valores
- `NOT IN` — Excluir múltiples valores
- `=` — Igualdad exacta
- `<>` — No igual
- `>`, `<`, `>=`, `<=` — Comparación numérica/fecha
- `CONTAINS` — Búsqueda de texto
