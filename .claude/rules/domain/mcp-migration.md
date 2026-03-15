---
globs: ["scripts/azdevops-queries.sh"]
---

# Migración REST/CLI → MCP — Guía de equivalencias

Mapeo entre las funciones de `scripts/azdevops-queries.sh` (REST API + az CLI)
y los MCP tools equivalentes de `@azure-devops/mcp`.

## Estado de migración

| Función script | MCP tool equivalente | Estado | Notas |
|---|---|---|---|
| `get_current_sprint` | `get_team_iterations` | ✅ Migrado | MCP devuelve iteraciones del equipo con fechas |
| `get_sprint_items` | `run_wiql_query` + `get_work_item` | ✅ Migrado | WIQL idéntico, get details por ID |
| `get_board_status` | `run_wiql_query` + `get_work_item` | ✅ Migrado | Misma WIQL, agrupar por estado en Claude |
| `update_workitem` | `update_work_item` | ✅ Migrado | MCP soporta update de campos |
| `batch_get_workitems` | `get_work_item` (por ID) | ✅ Migrado | Llamar por cada ID (MCP no tiene batch nativo) |
| `get_burndown_data` | ❌ No hay equivalente MCP | 🟡 Mantener script | Requiere Analytics OData, MCP no lo cubre |
| `get_team_capacities` | ❌ No hay equivalente MCP | 🟡 Mantener script | Requiere Work API (capacities), MCP no lo cubre |
| `get_velocity_history` | `get_team_iterations` (parcial) | 🟡 Híbrido | MCP da iteraciones, velocity requiere cálculo con SP completados por sprint |

## Regla de decisión

```
¿La operación es CRUD de work items?
  → Sí → Usar MCP tool (run_wiql_query, get_work_item, create_work_item, update_work_item)
  → No → ¿Es Analytics / OData / Capacities?
    → Sí → Mantener scripts/azdevops-queries.sh
    → No → Evaluar caso por caso
```

## MCP tools para CRUD de work items

### Lectura
- `run_wiql_query` — Ejecutar cualquier WIQL query (equivale a todas las queries del script)
- `get_work_item` — Obtener detalle de un work item por ID
- `search_work_items` — Búsqueda full-text en work items

### Escritura
- `create_work_item` — Crear PBI, Bug, Task, etc.
- `update_work_item` — Actualizar campos de un work item
- `add_work_item_comment` — Añadir comentario a un work item

### Relaciones
- `manage_work_item_link` — Crear/eliminar links entre work items (parent, related, etc.)

## Funciones que DEBEN mantenerse en el script

1. **`get_burndown_data`** — Usa Analytics OData endpoint (`_odata/v4.0-preview/WorkItemSnapshot`)
   que no está cubierto por ningún MCP tool. Necesario para dashboards de burndown.

2. **`get_team_capacities`** — Usa Work API (`teamsettings/iterations/{id}/capacities`)
   que no está cubierto por MCP. Necesario para `/report-capacity` y `/project-assign`.

3. **`get_velocity_history`** (parcial) — MCP puede listar iteraciones (`get_team_iterations`)
   pero el cálculo de SP completados por sprint requiere WIQL por cada iteración.

## Cómo usar MCP en lugar del script

### Antes (script):
```bash
./scripts/azdevops-queries.sh items ProyectoAlpha
```

### Ahora (MCP via Claude):
```
PM: /sprint-status --project sala-reservas
→ Claude usa MCP: run_wiql_query con la WIQL del sprint actual
→ Claude usa MCP: get_work_item para cada ID
→ Claude formatea y presenta el dashboard
```

El PM ya no necesita ejecutar el script directamente. Los comandos de pm-workspace
invocan los MCP tools internamente. El script se mantiene solo para funciones
sin equivalente MCP (burndown, capacities) que los comandos invocan con `bash`.
