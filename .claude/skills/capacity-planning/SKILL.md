---
name: capacity-planning
description: Gestión completa de capacidades del equipo - consulta, cálculo y alertas
context: fork
agent: azure-devops-operator
context_cost: medium
---

# Skill: capacity-planning

> Gestión completa de capacidades del equipo: consulta, cálculo y alertas de sobre-asignación.

**Prerequisito:** Leer primero `.claude/skills/azure-devops-queries/SKILL.md`

## Constantes de esta skill

```bash
TEAM_HOURS_PER_DAY=8          # horas de trabajo por día
TEAM_FOCUS_FACTOR=0.75        # 75% del tiempo es productivo
OVERLOAD_THRESHOLD=1.0        # > 100% = sobre-cargado
WARNING_THRESHOLD=0.85        # > 85% = al límite

ITERATIONS_API="$ORG_URL/$PROJECT/$TEAM/_apis/work/teamsettings/iterations"
```

---

## Flujo 1 — Obtener el ID de la Iteración Actual

```bash
PAT=$(cat $AZURE_DEVOPS_PAT_FILE)
AUTH="Authorization: Basic $(echo -n ":$PAT" | base64)"

ITER_RESPONSE=$(curl -s "$ITERATIONS_API?\$timeframe=current&api-version=7.1" \
  -H "$AUTH" -H "Content-Type: application/json")

ITER_ID=$(echo $ITER_RESPONSE | jq -r '.value[0].id')
ITER_NAME=$(echo $ITER_RESPONSE | jq -r '.value[0].name')
```

---

## Flujo 2 — Consultar Capacidades Configuradas

```bash
CAPACITIES=$(curl -s "$ITERATIONS_API/$ITER_ID/capacities?api-version=7.1" -H "$AUTH")
echo $CAPACITIES | jq '.value[] | {persona: .teamMember.displayName, capacidadDia: .activities[0].capacityPerDay}'
```

Formato esperado: `{displayName, uniqueName, activities[], daysOff[]}`

---

## Flujo 3 — Consultar Días Off del Equipo

```bash
TEAM_DAYS_OFF=$(curl -s "$ITERATIONS_API/$ITER_ID/teamdaysoff?api-version=7.1" -H "$AUTH")
echo $TEAM_DAYS_OFF | jq '.daysOff[] | {start, end}'
```

---

## Flujo 4 — Calcular Horas Disponibles Reales

> Detalle: @references/capacity-formula.md

Algoritmo:
1. Contar días hábiles entre inicio-fin del sprint
2. Restar días off (persona + equipo)
3. Aplicar factor de foco (75%)

Fórmula: `horas_disponibles = (dias_habiles - dias_off) * horas_dia * factor_foco`

---

## Flujo 5 — Calcular Utilización vs Carga Asignada

Obtener RemainingWork por persona desde WIQL y cruzar con capacidad calculada:

```bash
Utilización = sum(RemainingWork por persona) / horas_disponibles_por_persona
```

**Umbrales:**
- 🔴 > 100% — SOBRE-CARGADO
- 🟡 85-100% — AL LÍMITE
- 🟢 < 85% — OK
- ⚪ Sin datos — SIN CONFIGURACIÓN

---

## Flujo 6 — Actualizar Capacidades en Azure DevOps

```bash
curl -s -X PATCH "$ITERATIONS_API/$ITER_ID/capacities/$TEAM_MEMBER_ID?api-version=7.1" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"activities": [{"name": "Development", "capacityPerDay": 6}], "daysOff": []}'
```

> ⚠️ Confirmar con usuario antes de ejecutar.

---

## Errores Frecuentes

| Error | Solución |
|-------|----------|
| `404` en capacities | Usar team ID en lugar de nombre |
| Capacidades vacías | Activar sprint en Team Settings |
| Festivos ignorados | Añadir manualmente via API o UI |

---

## Referencias

- `references/capacity-formula.md` — Fórmulas de cálculo
- `references/capacity-api.md` — Estructura respuesta API
- Sprint management: `../sprint-management/SKILL.md`
- Comando: `/report-capacity`
