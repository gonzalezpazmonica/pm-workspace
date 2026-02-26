---
name: linear-sync
description: >
  Sincronizar issues de Linear con PBIs/Tasks de Azure DevOps.
  Para equipos que usan Linear como tracker principal junto a Azure DevOps.
---

# Sync Linear ↔ Azure DevOps

**Argumentos:** $ARGUMENTS

> Uso: `/linear:sync --project {p}` o `/linear:sync --project {p} --cycle {nombre}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace
- `--direction {linear-to-devops|devops-to-linear|bidirectional}` — Dirección (defecto: bidirectional)
- `--cycle {nombre}` — Filtrar por ciclo de Linear (equivale a sprint)
- `--team {nombre}` — Equipo de Linear (defecto: `LINEAR_DEFAULT_TEAM`)
- `--label {etiqueta}` — Filtrar issues por label en Linear
- `--dry-run` — Solo mostrar cambios propuestos
- `--since {fecha}` — Solo sincronizar cambios desde esta fecha (YYYY-MM-DD)

## Contexto requerido

1. `.claude/rules/connectors-config.md` — Verificar Linear habilitado
2. `projects/{proyecto}/CLAUDE.md` — `LINEAR_DEFAULT_TEAM`, `AZURE_DEVOPS_PROJECT`
3. `projects/{proyecto}/equipo.md` — Para mapeo de asignaciones

## Mapeo de campos

| Linear | Azure DevOps |
|---|---|
| Title | Title (prefijado `[LIN#ID]`) |
| Description (markdown) | Description |
| Issue Type (Issue/Bug/Feature) | Work Item Type (Task/Bug/PBI) |
| Priority (Urgent→Low) | Priority (1→4) |
| Cycle | Iteration Path |
| Assignee | Assigned To (mapeo via equipo.md) |
| State | State (mapeo configurable) |
| Estimate (puntos) | Story Points |
| Labels | Tags |
| Project | Area Path |
| Parent Issue | Parent (Feature/PBI) |

## Mapeo de estados (configurable)

| Linear State | Azure DevOps State |
|---|---|
| Backlog / Triage | New |
| Todo / In Progress / In Review | Active |
| Done / Canceled | Closed |

## Pasos de ejecución

1. **Verificar conector** — Comprobar Linear disponible
2. **Leer configuración** del proyecto: LINEAR_DEFAULT_TEAM, mapeo de usuarios
3. **Obtener issues** de Linear (filtro por cycle, team, label)
4. **Obtener work items** de Azure DevOps (filtro por IterationPath)
5. **Detectar correspondencias** por `[LIN#ID]` en título de DevOps
6. **Calcular diff**:
   - Nuevos en Linear → proponer crear en DevOps
   - Nuevos en DevOps → proponer crear en Linear (si bidirectional)
   - Cambios en ambos → detectar conflicto, proponer resolución
7. **Presentar propuesta**:
   ```
   ## Sync Linear ↔ Azure DevOps — {proyecto}
   | Acción | Linear | Azure DevOps | Campo |
   |---|---|---|---|
   | CREATE → | LIN-123 | (nuevo) | Feature: API Gateway |
   | UPDATE → | LIN-124 | AB#456 | State: Done → Closed |
   | ← UPDATE | (actualizar) | AB#789 | Estimate: 3 → 5 |
   | ⚠️ CONFLICT | LIN-125 | AB#790 | Ambos modificados |
   ```
8. **Confirmar con PM** — NUNCA sincronizar sin confirmación
9. Si confirmado → ejecutar cambios en ambos sistemas

## Integración con otros comandos

- `/sprint:plan` puede considerar issues de Linear como candidatos
- `/board:flow` puede incluir métricas de cycle time de Linear
- `/kpi:dashboard` puede agregar métricas de ambos trackers
- Soporta `--notify-slack` para publicar resumen del sync

## Restricciones

- **NUNCA sincronizar sin confirmación** del PM
- Conflictos se resuelven manualmente
- Si `--dry-run` → solo mostrar propuesta
- Máximo 50 items por ejecución
- No eliminar issues en ningún sistema — solo crear y actualizar
- No crear ciclos en Linear — solo usar existentes
