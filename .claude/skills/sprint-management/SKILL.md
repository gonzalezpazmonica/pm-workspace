---
name: sprint-management
description: Flujo completo de gestión de sprints - estado, items, progreso y resúmenes
context: fork
agent: azure-devops-operator
---

# Skill: sprint-management

> Flujo completo de gestión de sprints: obtener estado, listar items, calcular progreso y generar resúmenes.

**Prerequisito:** Leer primero `.claude/skills/azure-devops-queries/SKILL.md`

## Constantes de esta skill

```bash
# Heredadas del entorno global
PROJECT_NAME="${AZURE_DEVOPS_DEFAULT_PROJECT}"
TEAM_NAME="${AZURE_DEVOPS_DEFAULT_TEAM}"
ORG_URL="${AZURE_DEVOPS_ORG_URL}"
SPRINT_DURATION_WEEKS=2        # semanas por sprint (ajustar si difiere)
VELOCITY_SPRINTS=5             # sprints para calcular media de velocity
```

---

## Flujo 1 — Obtener el Sprint Actual

```bash
# Paso 1: Obtener el sprint activo del equipo
az devops configure --defaults organization=$ORG_URL project=$PROJECT_NAME
az boards iteration team list \
  --project "$PROJECT_NAME" \
  --team "$TEAM_NAME" \
  --timeframe current \
  --output json > /tmp/current-sprint.json

# Extraer campos clave
cat /tmp/current-sprint.json | jq '{
  id: .value[0].id,
  name: .value[0].name,
  startDate: .value[0].attributes.startDate,
  finishDate: .value[0].attributes.finishDate,
  iterationPath: .value[0].path
}'
```

**Calcular días restantes:**
```bash
FINISH=$(cat /tmp/current-sprint.json | jq -r '.value[0].attributes.finishDate' | cut -c1-10)
TODAY=$(date +%Y-%m-%d)
DAYS_LEFT=$(( ($(date -d "$FINISH" +%s) - $(date -d "$TODAY" +%s)) / 86400 ))
echo "Días restantes: $DAYS_LEFT"
```

---

## Flujo 2 — Obtener Work Items del Sprint

```bash
# Ejecutar query WIQL (ver wiql-patterns.md para la query completa)
WIQL='{"query": "SELECT [System.Id],[System.Title],[System.State],[System.AssignedTo],[System.WorkItemType],[Microsoft.VSTS.Scheduling.CompletedWork],[Microsoft.VSTS.Scheduling.RemainingWork],[Microsoft.VSTS.Scheduling.StoryPoints] FROM WorkItems WHERE [System.IterationPath] UNDER @CurrentIteration AND [System.TeamProject] = @Project ORDER BY [System.AssignedTo] ASC"}'

PAT=$(cat $AZURE_DEVOPS_PAT_FILE)
curl -s -X POST \
  "$ORG_URL/$PROJECT_NAME/_apis/wit/wiql?api-version=7.1" \
  -H "Authorization: Basic $(echo -n ":$PAT" | base64)" \
  -H "Content-Type: application/json" \
  -d "$WIQL" | jq '.workItems[].id' > /tmp/sprint-ids.json

echo "Items encontrados: $(wc -l < /tmp/sprint-ids.json)"
```

---

## Flujo 3 — Calcular Progreso del Sprint

Una vez obtenidos los work items, calcular las métricas:

```bash
# Con los datos en JSON, calcular:
# 1. Total Story Points planificados vs completados
# 2. Total RemainingWork del equipo
# 3. Distribución por estado
# 4. Distribución por persona

python3 scripts/capacity-calculator.py \
  --items /tmp/sprint-items.json \
  --sprint-days-left $DAYS_LEFT \
  --team-hours-per-day $TEAM_HOURS_PER_DAY \
  --focus-factor $TEAM_FOCUS_FACTOR
```

**Cálculo manual (si no se usa el script):**
```
SP completados = sum(StoryPoints donde State IN ('Done','Closed','Resolved'))
SP planificados = sum(StoryPoints de todos los PBIs del sprint)
Progreso % = SP_completados / SP_planificados * 100

RemainingWork total = sum(RemainingWork de todos los Tasks activos)
Capacity restante = DAYS_LEFT * TEAM_HOURS_PER_DAY * TEAM_FOCUS_FACTOR * num_personas
Riesgo = RemainingWork_total > Capacity_restante
```

---

## Flujo 4 — Velocity y Tendencia

```bash
# Obtener los últimos N sprints y sus SP completados
az boards iteration team list \
  --project "$PROJECT_NAME" \
  --team "$TEAM_NAME" \
  --output json | jq '.value[] | select(.attributes.timeFrame == "past") | {name: .name, id: .id}' \
  | head -n $VELOCITY_SPRINTS > /tmp/past-sprints.json

# Para cada sprint pasado, ejecutar la query de SP completados
# (ver Patrón 3 en wiql-patterns.md)
# Calcular media: sum(SP_por_sprint) / num_sprints
```

---

## Flujo 5 — Generar Resumen de Sprint

Una vez calculadas las métricas, estructurar el output:

```markdown
## Estado del Sprint — [Nombre Sprint]
**Período:** [startDate] → [finishDate] | **Días restantes:** X

### Progreso
- Story Points: X/Y completados (Z%)
- Remaining Work: Xh / Capacity restante: Yh
- Items: X Done, Y Active, Z New

### Por Persona
| Persona | Items Active | Remaining (h) | Alerta |
| ...     | ...          | ...           | ...    |

### Alertas
- [lista de alertas por WIP, sobre-capacidad, bugs críticos]
```

---

## Guardar Snapshot del Sprint

Guardar el estado diario para análisis histórico:

```bash
DATE=$(date +%Y%m%d)
SPRINT_DIR="projects/$PROJECT_NAME/sprints/$SPRINT_NAME"
mkdir -p "$SPRINT_DIR/snapshots"
# Guardar JSON con estado de hoy
cp /tmp/sprint-items.json "$SPRINT_DIR/snapshots/$DATE-items.json"
```

---

## Errores Frecuentes

| Situación | Acción |
|-----------|--------|
| Sprint no activo (`timeframe=current` vacío) | Verificar que el sprint esté configurado en Azure DevOps Team Settings |
| Items sin StoryPoints | Marcarlos en el output con ⚠️ y notificar; no afectar el denominador de velocity |
| RemainingWork = null | Tratar como 0 para el cálculo, pero alertar al equipo |
| Más de 200 items en sprint | Usar paginación (ver wiql-patterns.md §Paginación) |

---

## Referencias
→ Patrones WIQL: `references/wiql-patterns.md`
→ Comandos disponibles: `/sprint-status`, `/sprint-plan`, `/sprint-review`, `/sprint-retro`
→ Para descomponer los PBIs del sprint en tasks: `../pbi-decomposition/SKILL.md` y `/pbi-plan-sprint`
