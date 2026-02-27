---
name: jira-sync
description: >
  Sincronizar issues de Jira con PBIs de Azure DevOps. Soporta sync
  bidireccional, mapeo de campos y detección de conflictos.
---

# Sync Jira ↔ Azure DevOps

**Argumentos:** $ARGUMENTS

> Uso: `/jira-sync --project {p}` o `/jira-sync --project {p} --direction {dir}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace
- `--direction {jira-to-devops|devops-to-jira|bidirectional}` — Dirección del sync (defecto: bidirectional)
- `--jql {query}` — Filtro JQL personalizado (ej: `sprint = "Sprint 2026-04"`)
- `--dry-run` — Solo mostrar cambios propuestos, no ejecutar
- `--since {fecha}` — Solo sincronizar cambios desde esta fecha (YYYY-MM-DD)

## Contexto requerido

1. `.claude/rules/connectors-config.md` — Verificar Atlassian habilitado
2. `projects/{proyecto}/CLAUDE.md` — `JIRA_PROJECT`, `AZURE_DEVOPS_PROJECT`

## Mapeo de campos

| Jira | Azure DevOps PBI |
|---|---|
| Summary | Title (prefijado `[Jira#KEY]`) |
| Description | Description |
| Issue Type (Story/Bug/Task) | Work Item Type (PBI/Bug/Task) |
| Priority (Highest→Lowest) | Priority (1→4) |
| Sprint | Iteration Path |
| Assignee | Assigned To (requiere mapeo en equipo.md) |
| Status | State (mapeo configurable) |
| Story Points | Story Points |
| Labels | Tags |
| Epic Link | Parent (Feature) |

## Mapeo de estados (configurable por proyecto)

| Jira Status | Azure DevOps State |
|---|---|
| To Do / Backlog | New |
| In Progress / In Review | Active |
| Done / Closed | Closed |

## Pasos de ejecución

1. **Verificar conector** — Comprobar Atlassian disponible
2. **Leer configuración** del proyecto: JIRA_PROJECT, mapeo de usuarios
3. **Obtener issues** de Jira (usando JQL o filtro por sprint)
4. **Obtener PBIs** de Azure DevOps (filtro por IterationPath)
5. **Detectar correspondencias** por `[Jira#KEY]` en título de DevOps
6. **Calcular diff**:
   - Nuevos en Jira → proponer crear en DevOps
   - Nuevos en DevOps → proponer crear en Jira (si bidirectional)
   - Cambios en ambos → detectar conflicto, proponer resolución
7. **Presentar propuesta**:
   ```
   ## Sync Jira ↔ Azure DevOps — {proyecto}

   | Acción | Jira | Azure DevOps | Campo |
   |---|---|---|---|
   | CREATE → | PROJ-123 | (nuevo) | Story: Login OAuth |
   | UPDATE → | PROJ-124 | AB#456 | Status: Done → Closed |
   | ← UPDATE | (actualizar) | AB#789 | Points: 5 → 8 |
   | ⚠️ CONFLICT | PROJ-125 | AB#790 | Ambos modificados |
   ```
8. **Confirmar con PM** — NUNCA sincronizar sin confirmación
9. Si confirmado → ejecutar cambios en ambos sistemas
10. **Resumen**: items creados, actualizados, conflictos pendientes

## Restricciones

- **NUNCA sincronizar sin confirmación** del PM
- Conflictos se resuelven manualmente (mostrar ambas versiones)
- Si `--dry-run` → solo mostrar propuesta
- Máximo 50 items por ejecución
- No eliminar items en ningún sistema — solo crear y actualizar
