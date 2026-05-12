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

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Infrastructure** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/tools.md`
   - `profiles/users/{slug}/projects.md`
3. Adaptar output según herramientas y entorno del usuario
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Nombre del proyecto en DevOps
2. `.claude/skills/azure-pipelines/SKILL.md` — MCP tools y reglas

## 4. Pasos de ejecución

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

## 5. Restricciones

- **NUNCA ejecutar sin confirmación** del PM
- **Deploys a PRO:** requieren mención explícita del PBI/Release
- Variables con `isSecret=true` NO se muestran en el preview
- Si la pipeline requiere approval gates → informar que se necesitará aprobación manual en Azure DevOps
- Timeout de `--watch`: 30 minutos máximo

## 6. Integración

- `/pipeline-status` → ver resultado tras ejecución
- `/pipeline-logs --build {id}` → si falla, ver logs
- `/notify-slack` → notificar al canal del proyecto
