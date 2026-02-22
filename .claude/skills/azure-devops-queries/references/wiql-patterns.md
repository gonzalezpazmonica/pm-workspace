# WIQL Patterns — Referencia Avanzada

> Fichero de referencia para la skill `azure-devops-queries`. Contiene patrones WIQL avanzados y ejemplos de casos de uso reales.

## Macros WIQL Disponibles

| Macro | Expansión |
|-------|-----------|
| `@CurrentIteration` | Sprint activo del equipo en contexto |
| `@CurrentIteration('[Project]\[Team]')` | Sprint activo de un equipo específico |
| `@Project` | Proyecto en contexto |
| `@Me` | Usuario autenticado actual |
| `@Today` | Fecha actual (YYYY-MM-DD) |
| `@StartOfDay`, `@StartOfWeek` | Inicio de día/semana actuales |

---

## Patrones por Caso de Uso

### Patrón 1 — Burndown manual (horas remaining por día)
```sql
SELECT [System.Id], [System.ChangedDate],
       [Microsoft.VSTS.Scheduling.RemainingWork]
FROM WorkItemLinks
WHERE [System.IterationPath] UNDER @CurrentIteration
  AND [System.WorkItemType] = 'Task'
  AND [System.ChangedDate] >= @Today - 14
ORDER BY [System.ChangedDate] ASC
```

### Patrón 2 — Items sin estimar (para refinement)
```sql
SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo]
FROM WorkItems
WHERE [System.WorkItemType] IN ('User Story','Product Backlog Item')
  AND [System.State] IN ('New','Approved')
  AND [Microsoft.VSTS.Scheduling.StoryPoints] = ''
  AND [System.TeamProject] = @Project
ORDER BY [Microsoft.VSTS.Common.Priority] ASC
```

### Patrón 3 — Velocity de los últimos N sprints
```sql
SELECT [System.Id], [System.IterationPath],
       [Microsoft.VSTS.Scheduling.StoryPoints]
FROM WorkItems
WHERE [System.WorkItemType] IN ('User Story','Product Backlog Item')
  AND [System.State] IN ('Done','Closed')
  AND [System.IterationPath] UNDER '[PROJECT]\Sprints'
  AND [System.ChangedDate] >= @Today - 70
ORDER BY [System.IterationPath] ASC
```
> Agrupar los resultados por IterationPath para calcular SP por sprint.

### Patrón 4 — Bugs escapados (post-release)
```sql
SELECT [System.Id], [System.Title], [System.CreatedDate],
       [Microsoft.VSTS.Common.Severity], [System.AssignedTo]
FROM WorkItems
WHERE [System.WorkItemType] = 'Bug'
  AND [System.Tags] CONTAINS 'PostRelease'
  AND [System.CreatedDate] >= '[FECHA_INICIO_RELEASE]'
ORDER BY [Microsoft.VSTS.Common.Severity] ASC
```

### Patrón 5 — Items bloqueados
```sql
SELECT [System.Id], [System.Title], [System.AssignedTo],
       [System.State], [System.Tags]
FROM WorkItems
WHERE [System.IterationPath] UNDER @CurrentIteration
  AND ([System.Tags] CONTAINS 'Blocked' OR [System.State] = 'Blocked')
ORDER BY [System.ChangedDate] ASC
```

### Patrón 6 — Cycle Time (items resueltos últimas 4 semanas)
```sql
SELECT [System.Id], [System.Title], [System.WorkItemType],
       [System.CreatedDate], [Microsoft.VSTS.Common.ActivatedDate],
       [Microsoft.VSTS.Common.ResolvedDate]
FROM WorkItems
WHERE [System.WorkItemType] IN ('User Story','Bug','Task')
  AND [System.State] IN ('Resolved','Done','Closed')
  AND [Microsoft.VSTS.Common.ResolvedDate] >= @Today - 28
  AND [System.TeamProject] = @Project
ORDER BY [Microsoft.VSTS.Common.ResolvedDate] DESC
```
> Cycle Time = ResolvedDate - ActivatedDate

### Patrón 7 — Dependencias entre proyectos (links)
```sql
SELECT [System.Id], [System.Title], [System.State],
       [System.TeamProject]
FROM WorkItemLinks
WHERE ([Source].[System.TeamProject] = '[PROJECT_A]'
   OR [Target].[System.TeamProject] = '[PROJECT_B]')
  AND [System.Links.LinkType] = 'System.LinkTypes.Dependency-Forward'
  AND [Source].[System.State] NOT IN ('Done','Closed')
MODE (MayContain)
```

### Patrón 8 — Items del sprint con estado de PR (via tags)
```sql
SELECT [System.Id], [System.Title], [System.State],
       [System.AssignedTo], [System.Tags]
FROM WorkItems
WHERE [System.IterationPath] UNDER @CurrentIteration
  AND ([System.Tags] CONTAINS 'PR:Open' OR [System.Tags] CONTAINS 'PR:Review')
ORDER BY [System.AssignedTo] ASC
```

---

## Campos de Fechas — Nombres exactos

```
System.CreatedDate           → Fecha de creación del item
System.ChangedDate           → Última modificación de cualquier campo
Microsoft.VSTS.Common.ActivatedDate    → Cuando pasó a Active/In Progress
Microsoft.VSTS.Common.ResolvedDate     → Cuando se marcó como Resolved
Microsoft.VSTS.Common.ClosedDate       → Cuando se cerró (Done/Closed)
Microsoft.VSTS.Common.StateChangeDate  → Último cambio de estado
```

---

## Notas sobre el Operador UNDER

`UNDER` en IterationPath incluye la iteración padre y todos sus hijos:
```sql
-- Incluye Sprint 2026-04 y cualquier sub-iteración
[System.IterationPath] UNDER '[PROJECT]\Sprints\Sprint 2026-04'

-- Solo el sprint exacto (sin hijos)
[System.IterationPath] = '[PROJECT]\Sprints\Sprint 2026-04'

-- Todos los sprints bajo Sprints/
[System.IterationPath] UNDER '[PROJECT]\Sprints'
```

---

## Paginación de Resultados

Azure DevOps REST API limita a 200 items por query WIQL por defecto.
Para datasets grandes usar `$top` y paginación:

```bash
# Primero obtener los IDs (máx 20,000)
az boards query --wiql "SELECT [System.Id] FROM WorkItems WHERE ..." \
  --project "$PROJECT" --output json > ids.json

# Luego obtener detalles en lotes de 200
# (usar el script scripts/azdevops-queries.sh función batch_get_workitems)
```
