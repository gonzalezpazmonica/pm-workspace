---
name: pipeline-run
description: >
  Ejecutar una pipeline de Azure Pipelines con confirmación previa.
  Soporta selección de branch, variables y stages.
---

# Pipeline Run

**Argumentos:** $ARGUMENTS

> Uso: `/pipeline-run --project {p} {pipeline}` o `/pipeline-run --project {p} {pipeline} --branch {b}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `{pipeline}` — Nombre o ID de la pipeline (obligatorio)
- `--branch {rama}` — Rama source (defecto: main)
- `--variables {key=val,...}` — Variables override (opcional)
- `--stage {nombre}` — Ejecutar solo un stage específico (opcional)
- `--watch` — Monitorizar estado hasta completar (opcional)

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Nombre del proyecto en DevOps
2. `.claude/skills/azure-pipelines/SKILL.md` — MCP tools y reglas

## Pasos de ejecución

1. **Resolver pipeline** — MCP `get_build_definitions` → buscar por nombre
   - Si no se encuentra → listar disponibles y pedir selección
2. **Preview** — MCP `preview_pipeline_run`:
   - Stages que se ejecutarán
   - Variables efectivas
   - Rama source
   - Pool/agent
3. **Presentar confirmación:**

```
## Ejecutar Pipeline — {nombre}

- Pipeline: backend-ci (#definitionId)
- Branch: feature/auth-oauth
- Stages: Build → Test → Deploy DEV
- Variables: ENV=dev, DEBUG=false
- Estimación: ~8 min (basado en media)

⚠️ ¿Confirmar ejecución? (S/N)
```

4. **CONFIRMAR con PM** → NUNCA ejecutar sin confirmación (regla 3)
5. **Ejecutar** — MCP `run_pipeline` con parámetros confirmados
6. **Resultado inmediato:**
   - Build ID y link directo a Azure DevOps
   - Si `--watch` → polling cada 15s con `get_build_status`
7. **Si `--watch`** → mostrar progreso:
   ```
   Build #143 — In Progress (3m 22s)
   Stage Build: succeeded (2m 10s)
   Stage Test: in progress...
   ```

## Restricciones

- **NUNCA ejecutar sin confirmación** del PM
- **Deploys a PRO:** requieren mención explícita del PBI/Release
- Variables con `isSecret=true` NO se muestran en el preview
- Si la pipeline requiere approval gates → informar que se necesitará aprobación manual en Azure DevOps
- Timeout de `--watch`: 30 minutos máximo

## Integración

- `/pipeline-status` → ver resultado tras ejecución
- `/pipeline-logs --build {id}` → si falla, ver logs
- `/notify-slack` → notificar al canal del proyecto
