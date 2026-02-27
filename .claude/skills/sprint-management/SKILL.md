---
name: sprint-management
description: Flujo completo de gestión de sprints - estado, items, progreso y resúmenes
context: fork
agent: azure-devops-operator
context_cost: medium
---

# Skill: sprint-management

> Flujo completo de gestión de sprints: obtener estado, listar items, calcular progreso y generar resúmenes.

**Prerequisito:** Leer primero `.claude/skills/azure-devops-queries/SKILL.md`

## Constantes de esta skill

```bash
PROJECT_NAME="${AZURE_DEVOPS_DEFAULT_PROJECT}"
TEAM_NAME="${AZURE_DEVOPS_DEFAULT_TEAM}"
ORG_URL="${AZURE_DEVOPS_ORG_URL}"
SPRINT_DURATION_WEEKS=2        # ajustar si difiere
VELOCITY_SPRINTS=5             # sprints para media de velocity
```

---

## Flujo 1 — Obtener el Sprint Actual

```bash
az devops configure --defaults organization=$ORG_URL project=$PROJECT_NAME
az boards iteration team list \
  --project "$PROJECT_NAME" \
  --team "$TEAM_NAME" \
  --timeframe current \
  --output json > /tmp/current-sprint.json

# Extraer: id, name, startDate, finishDate, iterationPath
```

**Calcular días restantes:**
```bash
FINISH=$(jq -r '.value[0].attributes.finishDate' /tmp/current-sprint.json | cut -c1-10)
DAYS_LEFT=$(( ($(date -d "$FINISH" +%s) - $(date +%s)) / 86400 ))
```

---

## Flujo 2 — Obtener Work Items del Sprint

Ejecutar WIQL para obtener IDs de items:

```bash
WIQL='{"query": "SELECT [System.Id],[System.Title],[System.State],[System.AssignedTo],[System.WorkItemType],[Microsoft.VSTS.Scheduling.CompletedWork],[Microsoft.VSTS.Scheduling.RemainingWork],[Microsoft.VSTS.Scheduling.StoryPoints] FROM WorkItems WHERE [System.IterationPath] UNDER @CurrentIteration AND [System.TeamProject] = @Project ORDER BY [System.AssignedTo] ASC"}'

# Ejecutar curl y guardar en /tmp/sprint-ids.json
```

---

## Flujo 3 — Calcular Progreso del Sprint

> Detalle: @references/progress-metrics.md

Métricas a calcular:
1. Story Points planificados vs completados
2. RemainingWork total del equipo
3. Distribución por estado
4. Distribución por persona

---

## Flujo 4 — Velocity y Tendencia

```bash
# Obtener últimos N sprints (past)
az boards iteration team list --project "$PROJECT_NAME" --team "$TEAM_NAME" \
  --output json | jq '.value[] | select(.attributes.timeFrame == "past")'

# Para cada sprint: ejecutar query de SP completados
# Media = sum(SP_por_sprint) / num_sprints
```

---

## Flujo 5 — Generar Resumen de Sprint

> Detalle: @references/sprint-summary-template.md

Estructura: Período | Progreso | Por Persona | Alertas

---

## Guardar Snapshot del Sprint

```bash
DATE=$(date +%Y%m%d)
SPRINT_DIR="projects/$PROJECT_NAME/sprints/$SPRINT_NAME"
mkdir -p "$SPRINT_DIR/snapshots"
cp /tmp/sprint-items.json "$SPRINT_DIR/snapshots/$DATE-items.json"
```

---

## Errores Frecuentes

| Situación | Solución |
|-----------|----------|
| Sprint vacío (`timeframe=current`) | Configurar sprint en Team Settings |
| Items sin StoryPoints | Marcar ⚠️, no afectar denominador |
| RemainingWork=null | Tratar como 0, notificar |
| > 200 items | Usar paginación WIQL |

---

## Referencias

- `references/progress-metrics.md` — Métricas de progreso
- `references/sprint-summary-template.md` — Plantilla resumen
- Azure DevOps Queries: `../azure-devops-queries/SKILL.md`
- Comandos: `/sprint-status`, `/sprint-plan`, `/sprint-review`
