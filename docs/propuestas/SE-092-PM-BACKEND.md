---
spec_id: SE-092
title: Bridge Azure DevOps/Jira — comandos PM con datos reales
status: APPROVED
approved_by: operator (2026-05-07)
priority: CRITICAL
effort: M
estimated_time: 90 min
depends_on: SPEC-127 (provider-agnostic env)
---

# SE-092 — Bridge Azure DevOps/Jira: comandos PM a datos reales

## Resumen

Savia tiene 400+ comandos de gestión de proyectos pero ninguno se conecta a Azure DevOps para leer/escribir datos reales. Los comandos como `/sprint-status`, `/board-flow`, `/capacity-forecast` operan sobre datos mock o estáticos. Esto convierte a Savia en un "asistente PM teórico" en vez de un "PM real".

Este spec implementa los 8 comandos PM core contra la Azure DevOps REST API v7.1, usando el PAT ya configurado y los proyectos definidos en `pm-config.md` / `pm-config.local.md`.

## Alcance

### Slice 1: Core queries (WIQL + REST) — ~30 min

Script `scripts/ado-bridge.sh` con funciones reutilizables:
- `ado_get(uri)` — GET contra Azure DevOps API con auth PAT
- `ado_post(uri, body)` — POST con body JSON
- `ado_patch(uri, body)` — PATCH para updates
- `ado_wiql(query)` — ejecutar WIQL y devolver work items
- Cache de 60s para queries repetidas (evita rate limiting)

### Slice 2: Comandos PM core — ~30 min

| Comando | Descripción | API endpoint |
|---|---|---|
| `/sprint-status` | Estado real del sprint: items por columna, burndown, blockers | `_apis/work/boardcolumns` + WIQL |
| `/board-flow` | WIP por columna, cuellos de botella, aging | `_apis/work/boards` |
| `/capacity-forecast` | Capacidad del equipo vs carga del sprint | `_apis/work/teamsettings/iterations` |
| `/my-tasks` | Work items asignados al PM configurado | WIQL `[Assigned to] = @Me` |
| `/pbi-status <id>` | Detalle completo de un PBI: tasks, blockers, history | `_apis/wit/workitems/{id}` |
| `/sprint-retro` | Datos del sprint cerrado: velocity, carry-over, completion rate | WIQL + analytics |
| `/team-capacity` | Días/hombre disponibles por miembro | `_apis/work/teamsettings/iterations/{id}/capacities` |
| `/workitem-create` | Crear Task/PBI via API | `_apis/wit/workitems/\$Task` PATCH |

### Slice 3: Output formateado — ~20 min

- Tablas ASCII para terminal (sin dependencias npm)
- Modo `--json` para consumo por scripts/agentes
- Modo `--summary` (1 línea) para inyección en contexto diario
- Colores para estados (red=blocked, green=done, yellow=in-progress)

### Slice 4: Tests + CI — ~10 min

- BATS tests con mock mode (`--mock` flag que usa JSON fixtures)
- Test fixture: `projects/test-project/ado-fixtures/` con respuestas mock
- Validación de formato WIQL (sin ejecutar contra API real)

## Diseño técnico

### `scripts/ado-bridge.sh`

```bash
#!/bin/bash
# ado-bridge.sh — Azure DevOps REST API v7.1 bridge
# Reads config from pm-config.md/pm-config.local.md
# Auth: PAT from $HOME/.azure/devops-pat
# Cache: 60s TTL for GET requests

ADO_ORG="${AZURE_DEVOPS_ORG_URL:-}"
ADO_PAT="${AZURE_DEVOPS_EXT_PAT:-$(cat $HOME/.azure/devops-pat 2>/dev/null)}"
ADO_API_VERSION="7.1"
CACHE_DIR="${TMPDIR:-/tmp}/ado-cache-${USER:-default}"
CACHE_TTL=60

ado_get() {
  local uri="$1"
  local cache_key; cache_key=$(echo "$uri" | sha256sum | cut -c1-16)
  local cache_file="${CACHE_DIR}/${cache_key}.json"
  if [[ -f "$cache_file" ]] && [[ $(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0))) -lt $CACHE_TTL ]]; then
    cat "$cache_file"
    return
  fi
  mkdir -p "$CACHE_DIR"
  local resp
  resp=$(curl -sS -H "Authorization: Basic $(echo -n ":$ADO_PAT" | base64)" "$ADO_ORG/$uri" 2>/dev/null)
  echo "$resp" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null > "$cache_file" || echo "$resp" > "$cache_file"
  cat "$cache_file"
}
```

### Comando `/sprint-status`

```bash
#!/bin/bash
# sprint-status.sh — Real sprint status from Azure DevOps
source scripts/savia-env.sh
source scripts/ado-bridge.sh

PROJECT="${1:-$AZURE_DEVOPS_PROJECT}"
TEAM="${2:-$AZURE_DEVOPS_TEAM}"
SPRINT="${3:-$(date +%Y-W%V)}"  # current sprint

# Get current iteration
ITERATION=$(ado_get "${PROJECT}/${TEAM}/_apis/work/teamsettings/iterations?\$timeframe=current")
# Get board columns with WIP
COLUMNS=$(ado_get "${PROJECT}/${TEAM}/_apis/work/boards/Stories/columns")
# WIQL for sprint items
WIQL="SELECT [System.Id],[System.Title],[System.State],[System.AssignedTo] FROM WorkItems WHERE [System.IterationPath] = '$SPRINT'"
ITEMS=$(ado_post "_apis/wit/wiql?\$top=100" "{\"query\":\"$WIQL\"}")

# Format output
echo "Sprint: $SPRINT"
echo "Items: $(echo "$ITEMS" | jq '.workItems | length')"
# ... format by column
```

## Acceptance Criteria

### AC-1: Query bridge funcional
- `bash scripts/ado-bridge.sh get "PM-Workspace/_apis/projects"` devuelve JSON válido
- Cache funciona (segunda llamada <50ms, primera <2s)
- Sin PAT → error claro "Configure PAT in ~/.azure/devops-pat"

### AC-2: Sprint status real
- `/sprint-status` muestra datos reales del sprint actual
- Columnas con conteo de items + WIP limits
- Blockers detectados (items en estado "Blocked" >24h)

### AC-3: Board flow
- `/board-flow` muestra WIP por columna
- Alerta si columna excede WIP limit
- Aging: items >5 días en misma columna

### AC-4: My tasks
- `/my-tasks` lista work items del PM configurado
- Prioridad, estado, horas estimadas

### AC-5: Mock mode
- `--mock` flag usa fixtures sin llamar a la API
- Tests pasan sin PAT ni acceso a Azure DevOps

### AC-6: Output modes
- `--json` produce JSON válido consumible por scripts
- `--summary` produce 1 línea para contexto diario
- Default: tabla ASCII legible

## Riesgos

| Riesgo | Mitigación |
|---|---|
| PAT expirado | Error claro con instrucciones de regeneración |
| Rate limiting | Cache 60s + máximo 10 queries/turn |
| Proyecto no configurado | Mostrar proyectos disponibles desde API |
| WIQL syntax error | Validar con regex antes de enviar; mostrar query que falló |

## Referencias

- Azure DevOps REST API v7.1: https://learn.microsoft.com/en-us/rest/api/azure/devops/
- pm-config.md: AZURE_DEVOPS_ORG_URL, PAT, PROJECT_XXX constants
- pm-config.local.md: project-specific config
