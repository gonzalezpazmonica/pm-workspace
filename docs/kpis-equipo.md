# KPIs del Equipo — Métricas y Umbrales

> Define los KPIs que Claude Code debe calcular, sus fuentes de datos y los umbrales para el semáforo de estado.

## Constantes de KPIs

```
VELOCITY_SPRINTS_MEDIA    = 5          # nº sprints para calcular media de velocity
CYCLE_TIME_P95_UMBRAL     = 10         # días; si P95 > 10 → investigar
LEAD_TIME_P95_UMBRAL      = 20         # días
CAPACITY_MIN_VERDE        = 0.70       # 70% mínimo para estar bien utilizado
CAPACITY_MAX_VERDE        = 0.90       # 90% máximo antes de sobre-carga
GOAL_HIT_RATE_MINIMO      = 0.80       # 80% de sprints deben cumplir el objetivo
BUG_ESCAPE_RATE_MAXIMO    = 0.05       # máximo 5% de bugs post-release
WIP_MAXIMO_PERSONA        = 2          # items Active simultáneos por persona
THROUGHPUT_MINIMO_SEMANA  = 3          # items Done por semana (para equipo de 4)
```

---

## KPI 1 — Velocity

**Definición:** Story Points completados (estado Done/Closed) por sprint.

**Cálculo:**
```sql
-- WIQL
SELECT SUM([Microsoft.VSTS.Scheduling.StoryPoints]) as velocity
FROM WorkItems
WHERE [System.IterationPath] = '[PROJECT]\Sprints\[SPRINT_NAME]'
  AND [System.State] IN ('Done','Closed','Resolved')
  AND [System.WorkItemType] IN ('User Story','Product Backlog Item','Bug')
```

**Semáforo:**
- 🟢 Verde: velocity ≥ 90% de la media de últimos 5 sprints
- 🟡 Amarillo: velocity entre 70% y 89% de la media
- 🔴 Rojo: velocity < 70% de la media

**Tendencia:** Gráfico de línea con los últimos 5 sprints. Alertar si hay 2 sprints consecutivos en rojo.

---

## KPI 2 — Sprint Burndown

**Definición:** Evolución diaria de RemainingWork total del sprint vs línea ideal.

**Cálculo:**
```
# Via Analytics OData
GET {org}/{project}/_odata/v4.0-preview/WorkItemSnapshot
  ?$filter=TeamProject eq '{project}'
    and IterationPath eq '{sprint_path}'
    and WorkItemType ne 'Epic'
  &$select=WorkItemId,RemainingWork,DateValue
  &$orderby=DateValue asc
```

**Línea ideal:**
```
remaining_ideal_día_N = remaining_total_inicial × (1 - N / total_días_sprint)
```

**Semáforo (en cualquier punto del sprint):**
- 🟢 Verde: remaining real ≤ remaining ideal
- 🟡 Amarillo: remaining real supera ideal entre 10% y 25%
- 🔴 Rojo: remaining real supera ideal en > 25%

---

## KPI 3 — Cycle Time

**Definición:** Días desde que un item pasa a Active hasta que se completa (Resolved/Done).

**Cálculo:**
```python
cycle_time = fecha_resolved - fecha_active   # en días hábiles

# Obtener via WorkItem Revisions (campo StateChangeDate o via Analytics)
# Calcular: media, mediana, P75, P95 para el sprint/período
```

**Semáforo (por P75):**
- 🟢 Verde: P75 ≤ 5 días
- 🟡 Amarillo: P75 entre 5 y 8 días
- 🔴 Rojo: P75 > 8 días

**Desglose útil:** Cycle Time por tipo de work item (User Story, Bug, Task) y por persona.

---

## KPI 4 — Lead Time

**Definición:** Días desde la creación del item hasta que se completa. Incluye tiempo en backlog.

**Cálculo:**
```python
lead_time = fecha_done - fecha_created   # en días naturales

# Obtener System.CreatedDate y Microsoft.VSTS.Common.ClosedDate
```

**Semáforo (por P75):**
- 🟢 Verde: P75 ≤ 14 días (dentro del sprint más refinement)
- 🟡 Amarillo: P75 entre 14 y 28 días
- 🔴 Rojo: P75 > 28 días (indica backlog sin depurar)

---

## KPI 5 — Capacity Utilization

**Definición:** Porcentaje de las horas disponibles del equipo que se han imputado.

**Cálculo:**
```
utilización = sum(CompletedWork) / capacity_disponible_real × 100

# Dónde:
# capacity_disponible_real = calculada en skill capacity-planning
# CompletedWork = suma de horas imputadas de todos los work items del sprint
```

**Semáforo:**
- 🟢 Verde: 70% ≤ utilización ≤ 90%
- 🟡 Amarillo: 60-69% (sub-utilizado) o 91-100% (al límite)
- 🔴 Rojo: < 60% (equipo no registrando horas) o > 100% (sobre-cargado)

---

## KPI 6 — Sprint Goal Hit Rate

**Definición:** Porcentaje de sprints en los que se ha cumplido el Sprint Goal.

**Cálculo:** Este KPI se calcula desde el historial local (Azure DevOps no lo trackea automáticamente):

```bash
# Se guarda en projects/<proyecto>/sprints/<sprint>/retro-actions.md
# Campo: "Sprint Goal: ✅ Cumplido / ⚠️ Parcial / ❌ No cumplido"

# Calcular:
cumplidos=$(grep -r "Sprint Goal: ✅" projects/*/sprints/*/retro-actions.md | wc -l)
parciales=$(grep -r "Sprint Goal: ⚠️" projects/*/sprints/*/retro-actions.md | wc -l)
total=$(ls projects/*/sprints/*/retro-actions.md | wc -l)
hit_rate=$(echo "scale=2; ($cumplidos + $parciales * 0.5) / $total * 100" | bc)
```

**Semáforo:**
- 🟢 Verde: hit rate ≥ 80%
- 🟡 Amarillo: hit rate entre 60% y 79%
- 🔴 Rojo: hit rate < 60%

---

## KPI 7 — Bug Escape Rate

**Definición:** Porcentaje de bugs encontrados en producción respecto al total de items entregados.

**Cálculo:**
```sql
-- Bugs post-release (con tag 'PostRelease' o creados después de la fecha de release)
SELECT COUNT(*) as bugs_produccion
FROM WorkItems
WHERE [System.WorkItemType] = 'Bug'
  AND [System.Tags] CONTAINS 'PostRelease'
  AND [System.CreatedDate] >= '[FECHA_RELEASE]'

-- Total items entregados en ese período
SELECT COUNT(*) as items_entregados
FROM WorkItems
WHERE [System.State] IN ('Done','Closed')
  AND [System.WorkItemType] IN ('User Story','PBI')
  AND [System.IterationPath] = '[SPRINT_PATH]'

-- bug_escape_rate = bugs_produccion / items_entregados
```

**Semáforo:**
- 🟢 Verde: bug escape rate ≤ 5%
- 🟡 Amarillo: 6% - 10%
- 🔴 Rojo: > 10%

---

## KPI 8 — Throughput

**Definición:** Número de items Done por unidad de tiempo (semana).

**Cálculo:**
```sql
-- Items completados por semana (vía Analytics OData)
GET {org}/{project}/_odata/v4.0-preview/WorkItems
  ?$filter=State in ('Done','Closed')
    and ClosedDate ge {fecha_inicio}
    and WorkItemType ne 'Task' and WorkItemType ne 'Epic'
  &$select=WorkItemId,ClosedDate
```

```python
# Agrupar por semana y calcular media
throughput_semanal = items_done / semanas_del_período
```

**Semáforo (para equipo de 4 personas):**
- 🟢 Verde: throughput ≥ 3 items/semana
- 🟡 Amarillo: 2 items/semana
- 🔴 Rojo: ≤ 1 item/semana

---

## Dashboard Completo — Tabla de KPIs

Formato para el comando `/kpi:dashboard`:

| KPI | Valor actual | Referencia | Semáforo | Tendencia |
|-----|-------------|------------|----------|-----------|
| Velocity | X SP | Media 5s: Y SP | 🟢/🟡/🔴 | 📈/📉/→ |
| Burndown | X% completado | Ideal: Y% | 🟢/🟡/🔴 | — |
| Cycle Time P75 | X días | Umbral: 5d | 🟢/🟡/🔴 | 📈/📉/→ |
| Lead Time P75 | X días | Umbral: 14d | 🟢/🟡/🔴 | 📈/📉/→ |
| Capacity | X% | 70-90% | 🟢/🟡/🔴 | — |
| Goal Hit Rate | X% | ≥ 80% | 🟢/🟡/🔴 | 📈/📉/→ |
| Bug Escape | X% | ≤ 5% | 🟢/🟡/🔴 | 📈/📉/→ |
| Throughput | X/semana | ≥ 3/semana | 🟢/🟡/🔴 | 📈/📉/→ |
