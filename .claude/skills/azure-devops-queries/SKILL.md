---
name: azure-devops-queries
description: Skill transversal para operaciones con Azure DevOps
context: fork
agent: azure-devops-operator
---

# Skill: azure-devops-queries

> Skill transversal. Léela SIEMPRE antes de cualquier operación con Azure DevOps.

## Constantes de esta skill

```bash
# Leer siempre desde el entorno (configuradas en .claude/.env y CLAUDE.md raíz)
ORG_URL="${AZURE_DEVOPS_ORG_URL}"          # https://dev.azure.com/MI-ORGANIZACION
ORG_NAME="${AZURE_DEVOPS_ORG_NAME}"        # MI-ORGANIZACION
PAT_FILE="${AZURE_DEVOPS_PAT_FILE}"        # $HOME/.azure/devops-pat
API_VERSION="${AZURE_DEVOPS_API_VERSION}"  # 7.1
```

---

## 1. Autenticación

### Opción A — Azure CLI (preferida)
```bash
# Configurar defaults una vez por sesión
az devops configure --defaults organization=$ORG_URL project=$PROJECT_NAME
export AZURE_DEVOPS_EXT_PAT=$(cat $PAT_FILE)

# Verificar conectividad
az devops project list --output table
```

### Opción B — REST API directa con curl
```bash
PAT=$(cat $PAT_FILE)
B64_PAT=$(echo -n ":$PAT" | base64)
# Usar en cada petición:
curl -H "Authorization: Basic $B64_PAT" \
     -H "Content-Type: application/json" \
     "$ORG_URL/$PROJECT/_apis/..."
```

---

## 2. Regla Crítica: Filtrar SIEMPRE por IterationPath

> ⚠️ SIEMPRE incluir filtro `[System.IterationPath] UNDER @CurrentIteration` en las queries WIQL, salvo que se pida explícitamente una query cross-sprint.

Sin este filtro, las queries devuelven TODOS los work items del proyecto desde el inicio, lo que satura el contexto y degrada la calidad de las respuestas.

---

## 3. Queries WIQL Fundamentales

### 3.1 Items del sprint actual con horas
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

**Ejecutar con CLI:**
```bash
az boards query --wiql "SELECT..." --project "$PROJECT_NAME" --output json | jq '.workItems[].id'
```

### 3.2 Bugs activos por severidad
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

### 3.3 Items por persona (carga actual)
```sql
SELECT [System.Id], [System.Title], [System.State],
       [System.AssignedTo], [Microsoft.VSTS.Scheduling.RemainingWork]
FROM WorkItems
WHERE [System.IterationPath] UNDER @CurrentIteration('[PROJECT_NAME]\[TEAM_NAME]')
  AND [System.State] IN ('Active','In Progress','New','Committed')
  AND [System.AssignedTo] = '[NOMBRE_PERSONA]'
ORDER BY [System.State] ASC
```

### 3.4 PBIs para sprint planning (backlog ordenado)
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

### 3.5 Items completados en el sprint (para velocity)
```sql
SELECT [System.Id], [System.Title],
       [Microsoft.VSTS.Scheduling.StoryPoints],
       [System.WorkItemType], [System.AssignedTo]
FROM WorkItems
WHERE [System.IterationPath] = '[PROJECT_NAME]\\Sprints\\[SPRINT_NAME]'
  AND [System.State] IN ('Done','Closed','Resolved')
  AND [System.WorkItemType] IN ('User Story','Product Backlog Item','Bug')
```

---

## 4. Operaciones CLI Frecuentes

### Listar sprints del equipo
```bash
az boards iteration team list \
  --project "$PROJECT_NAME" \
  --team "$TEAM_NAME" \
  --output table
```

### Obtener detalles de un sprint
```bash
az boards iteration team show \
  --project "$PROJECT_NAME" \
  --team "$TEAM_NAME" \
  --id "[iteration-id]"
```

### Obtener work item por ID
```bash
az boards work-item show --id XXXX --output json
```

### Actualizar horas de un work item
```bash
az boards work-item update --id XXXX \
  --fields "Microsoft.VSTS.Scheduling.CompletedWork=8" \
           "Microsoft.VSTS.Scheduling.RemainingWork=4"
```

### Crear work item (Task)
```bash
az boards work-item create \
  --project "$PROJECT_NAME" \
  --type "Task" \
  --title "Descripción de la tarea" \
  --fields "System.AssignedTo=nombre@empresa.com" \
           "Microsoft.VSTS.Scheduling.OriginalEstimate=8" \
           "System.IterationPath=$PROJECT_NAME\\Sprints\\Sprint 2026-04"
```

---

## 5. REST API Directa — Endpoints Clave

```bash
BASE="$ORG_URL/$PROJECT/_apis"
BASE_TEAM="$ORG_URL/$PROJECT/$TEAM/_apis"

# Capacidades del sprint
GET $BASE_TEAM/work/teamsettings/iterations/{iterationId}/capacities?api-version=$API_VERSION

# Días off del equipo
GET $BASE_TEAM/work/teamsettings/iterations/{iterationId}/teamdaysoff?api-version=$API_VERSION

# Analytics OData — Snapshot diario (burndown)
GET $ORG_URL/$PROJECT/_odata/v4.0-preview/WorkItemSnapshot?\$filter=...

# Board columns y WIP limits
GET $BASE_TEAM/work/boards/{boardName}?api-version=$API_VERSION

# Obtener ID de iteración actual
GET $BASE_TEAM/work/teamsettings/iterations?\$timeframe=current&api-version=$API_VERSION
```

---

## 6. Campos WIQL — Referencia Rápida

| Campo | Alias | Descripción |
|-------|-------|-------------|
| `System.Id` | ID | Identificador del work item |
| `System.Title` | Title | Título |
| `System.State` | State | Estado (New, Active, Resolved, Closed, Done) |
| `System.AssignedTo` | AssignedTo | Persona asignada |
| `System.WorkItemType` | WorkItemType | User Story, Task, Bug, PBI, Epic, Feature |
| `System.IterationPath` | IterationPath | Ruta de iteración/sprint |
| `System.CreatedDate` | CreatedDate | Fecha de creación |
| `System.ChangedDate` | ChangedDate | Última modificación |
| `Microsoft.VSTS.Scheduling.StoryPoints` | StoryPoints | Puntos de historia |
| `Microsoft.VSTS.Scheduling.OriginalEstimate` | OriginalEstimate | Estimación original (h) |
| `Microsoft.VSTS.Scheduling.RemainingWork` | RemainingWork | Horas restantes |
| `Microsoft.VSTS.Scheduling.CompletedWork` | CompletedWork | Horas completadas |
| `Microsoft.VSTS.Common.Activity` | Activity | Tipo actividad (Development, Testing…) |
| `Microsoft.VSTS.Common.Priority` | Priority | Prioridad (1-4) |
| `Microsoft.VSTS.Common.Severity` | Severity | Severidad (bugs) |

---

## 7. Errores Comunes y Soluciones

| Error | Causa probable | Solución |
|-------|---------------|----------|
| `TF400813: The user is not authorized` | PAT expirado o scope insuficiente | Regenerar PAT con scopes correctos |
| `VS403501: The query returned too many results` | Sin filtro IterationPath | Añadir filtro UNDER @CurrentIteration |
| `TF26027: Iteration not found` | IterationPath incorrecto | Verificar con `az boards iteration team list` |
| `400 Bad Request en capacities API` | Team name con espacios sin encodear | Encodear URL o usar el team ID |
| Resultados vacíos en @CurrentIteration | Sprint no configurado en el equipo | Configurar sprint activo en AzDevOps Settings |

---

## 8. Referencias Adicionales

→ Patrones WIQL avanzados: `references/wiql-patterns.md`
→ Queries de Analytics OData: `references/odata-patterns.md`
