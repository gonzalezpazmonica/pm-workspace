# Skill: capacity-planning

> Gestión completa de capacidades del equipo: consulta, cálculo y alertas de sobre-asignación.

**Prerequisito:** Leer primero `.claude/skills/azure-devops-queries/SKILL.md`

## Constantes de esta skill

```bash
TEAM_HOURS_PER_DAY=8          # horas de trabajo por día (ajustar por persona si varía)
TEAM_FOCUS_FACTOR=0.75        # factor de foco: 75% del tiempo es productivo
OVERLOAD_THRESHOLD=1.0        # > 100% = sobre-cargado
WARNING_THRESHOLD=0.85        # > 85% = al límite (amarillo)

# Endpoints
ITERATIONS_API="$ORG_URL/$PROJECT/$TEAM/_apis/work/teamsettings/iterations"
```

---

## Flujo 1 — Obtener el ID de la Iteración Actual

```bash
PAT=$(cat $AZURE_DEVOPS_PAT_FILE)
AUTH="Authorization: Basic $(echo -n ":$PAT" | base64)"

# Obtener iteración actual
ITER_RESPONSE=$(curl -s \
  "$ITERATIONS_API?\$timeframe=current&api-version=7.1" \
  -H "$AUTH" -H "Content-Type: application/json")

ITER_ID=$(echo $ITER_RESPONSE | jq -r '.value[0].id')
ITER_NAME=$(echo $ITER_RESPONSE | jq -r '.value[0].name')
ITER_START=$(echo $ITER_RESPONSE | jq -r '.value[0].attributes.startDate' | cut -c1-10)
ITER_END=$(echo $ITER_RESPONSE | jq -r '.value[0].attributes.finishDate' | cut -c1-10)

echo "Sprint: $ITER_NAME ($ITER_START → $ITER_END) | ID: $ITER_ID"
```

---

## Flujo 2 — Consultar Capacidades Configuradas

```bash
# Obtener capacidades de cada miembro del equipo
CAPACITIES=$(curl -s \
  "$ITERATIONS_API/$ITER_ID/capacities?api-version=7.1" \
  -H "$AUTH")

echo $CAPACITIES | jq '.value[] | {
  persona: .teamMember.displayName,
  email: .teamMember.uniqueName,
  actividades: .activities,
  diasOff: .daysOff
}'
```

**Formato de respuesta esperado:**
```json
{
  "teamMember": { "displayName": "Juan García", "uniqueName": "juan@empresa.com" },
  "activities": [{ "name": "Development", "capacityPerDay": 6 }],
  "daysOff": [{ "start": "2026-03-05T00:00:00Z", "end": "2026-03-05T00:00:00Z" }]
}
```

---

## Flujo 3 — Consultar Días Off del Equipo

```bash
# Días off del equipo (festivos, vacaciones colectivas)
TEAM_DAYS_OFF=$(curl -s \
  "$ITERATIONS_API/$ITER_ID/teamdaysoff?api-version=7.1" \
  -H "$AUTH")

echo $TEAM_DAYS_OFF | jq '.daysOff[] | {start: .start, end: .end}'
```

---

## Flujo 4 — Calcular Horas Disponibles Reales

```python
# Algoritmo de cálculo (usar en scripts/capacity-calculator.py)

def calcular_horas_disponibles(fecha_inicio, fecha_fin, dias_off_persona, dias_off_equipo, horas_dia, factor_foco):
    """
    fecha_inicio, fecha_fin: datetime
    dias_off_persona: list de fechas [(start, end)]
    dias_off_equipo: list de fechas [(start, end)]
    horas_dia: float (capacidad configurada en AzDO o TEAM_HOURS_PER_DAY)
    factor_foco: float (TEAM_FOCUS_FACTOR)
    """
    dias_sprint = dias_habiles_entre(fecha_inicio, fecha_fin)  # excluye sábados y domingos

    # Restar días off
    dias_off = union(dias_off_persona, dias_off_equipo)
    dias_disponibles = dias_sprint - len(dias_off)

    # Aplicar factor de foco
    horas_disponibles = dias_disponibles * horas_dia * factor_foco
    return max(0, horas_disponibles)

# Fórmula resumida:
# horas_disponibles = (dias_habiles_sprint - dias_off) * horas_dia * factor_foco
```

---

## Flujo 5 — Calcular Utilización vs Carga Asignada

```bash
# Obtener RemainingWork por persona desde WIQL
WIQL_QUERY='{"query": "SELECT [System.AssignedTo], [Microsoft.VSTS.Scheduling.RemainingWork] FROM WorkItems WHERE [System.IterationPath] UNDER @CurrentIteration AND [System.State] NOT IN ('"'"'Done'"'"','"'"'Closed'"'"')"}'

# Cruzar con horas_disponibles calculadas
# Utilización = sum(RemainingWork por persona) / horas_disponibles_por_persona
```

**Umbrales de alerta:**
```
utilización > 100% → 🔴 SOBRE-CARGADO — redistribuir trabajo
utilización 85-100% → 🟡 AL LÍMITE — vigilar de cerca
utilización < 85% → 🟢 OK
sin capacidad configurada → ⚪ SIN DATOS — configurar en AzDO
```

---

## Flujo 6 — Actualizar Capacidades en Azure DevOps

```bash
# Establecer capacidad de una persona para el sprint
curl -s -X PATCH \
  "$ITERATIONS_API/$ITER_ID/capacities/$TEAM_MEMBER_ID?api-version=7.1" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "activities": [{ "name": "Development", "capacityPerDay": 6 }],
    "daysOff": []
  }'
```

> ⚠️ Operación de escritura — confirmar con el usuario antes de ejecutar.

---

## Configurar Días Off de un Miembro

```bash
curl -s -X PATCH \
  "$ITERATIONS_API/$ITER_ID/capacities/$TEAM_MEMBER_ID?api-version=7.1" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "daysOff": [
      { "start": "2026-03-10T00:00:00Z", "end": "2026-03-14T00:00:00Z" }
    ]
  }'
```

---

## Errores Frecuentes

| Error | Causa | Solución |
|-------|-------|----------|
| `404` en capacities endpoint | Team name incorrecto en URL | Usar team ID en lugar de nombre |
| Capacidades vacías para todos | Sprint no configurado para el equipo | Activar sprint en Team Settings |
| `daysOff` ignora festivos nacionales | Azure DevOps no los incluye automáticamente | Añadir festivos manualmente via API o en la UI |
| `capacityPerDay: 0` para todos | Primera vez usando capacity | Configurar via UI o PATCH por persona |

---

## Referencias
→ Skill principal: `azure-devops-queries/SKILL.md`
→ Script de cálculo: `scripts/capacity-calculator.py`
→ Comando: `/report:capacity`
→ Esta skill es prerequisito de `pbi-decomposition/SKILL.md` (Fase 4: perfil de disponibilidad del equipo)
