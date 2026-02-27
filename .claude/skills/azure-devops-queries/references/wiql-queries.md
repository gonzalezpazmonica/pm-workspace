# WIQL Queries — Fundamentales

## Query 1: Items del sprint actual con horas

```sql
SELECT [System.Id], [System.Title], [System.State],
       [System.AssignedTo], [System.WorkItemType],
       [Microsoft.VSTS.Scheduling.CompletedWork],
       [Microsoft.VSTS.Scheduling.RemainingWork],
       [Microsoft.VSTS.Scheduling.OriginalEstimate],
       [Microsoft.VSTS.Scheduling.StoryPoints],
       [Microsoft.VSTS.Common.Activity]
FROM WorkItems
WHERE [System.IterationPath] UNDER @CurrentIteration('[PROJECT_NAME]\[TEAM_NAME]')
  AND [System.TeamProject] = '[PROJECT_NAME]'
  AND [System.WorkItemType] IN ('User Story','Task','Bug','Product Backlog Item')
ORDER BY [System.AssignedTo] ASC, [System.State] ASC
```

## Query 2: Bugs activos por severidad

```sql
SELECT [System.Id], [System.Title], [System.State],
       [Microsoft.VSTS.Common.Severity], [System.AssignedTo],
       [System.CreatedDate]
FROM WorkItems
WHERE [System.WorkItemType] = 'Bug'
  AND [System.State] NOT IN ('Closed','Resolved','Done')
  AND [System.IterationPath] UNDER @CurrentIteration('[PROJECT_NAME]\[TEAM_NAME]')
ORDER BY [Microsoft.VSTS.Common.Severity] ASC
```

## Query 3: Items por persona (carga actual)

```sql
SELECT [System.Id], [System.Title], [System.State],
       [System.AssignedTo], [Microsoft.VSTS.Scheduling.RemainingWork]
FROM WorkItems
WHERE [System.IterationPath] UNDER @CurrentIteration('[PROJECT_NAME]\[TEAM_NAME]')
  AND [System.State] IN ('Active','In Progress','New','Committed')
  AND [System.AssignedTo] = '[NOMBRE_PERSONA]'
ORDER BY [System.State] ASC
```

## Query 4: PBIs para sprint planning

```sql
SELECT [System.Id], [System.Title], [System.State],
       [Microsoft.VSTS.Scheduling.StoryPoints],
       [Microsoft.VSTS.Common.Priority],
       [System.Description]
FROM WorkItems
WHERE [System.WorkItemType] IN ('User Story','Product Backlog Item','Feature')
  AND [System.State] IN ('New','Approved','Committed')
  AND [System.TeamProject] = '[PROJECT_NAME]'
  AND [System.IterationPath] = '[PROJECT_NAME]\\Backlog'
ORDER BY [Microsoft.VSTS.Common.Priority] ASC, [Microsoft.VSTS.Scheduling.StoryPoints] ASC
```

## Query 5: Items completados en el sprint

```sql
SELECT [System.Id], [System.Title],
       [Microsoft.VSTS.Scheduling.StoryPoints],
       [System.WorkItemType], [System.AssignedTo]
FROM WorkItems
WHERE [System.IterationPath] = '[PROJECT_NAME]\\Sprints\\[SPRINT_NAME]'
  AND [System.State] IN ('Done','Closed','Resolved')
  AND [System.WorkItemType] IN ('User Story','Product Backlog Item','Bug')
```
