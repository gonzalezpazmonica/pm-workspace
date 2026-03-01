---
name: pipeline-logs
description: >
  Ver logs de una build de Azure Pipelines: timeline de stages,
  errores, warnings y duración por paso.
---

# Pipeline Logs

**Argumentos:** $ARGUMENTS

> Uso: `/pipeline-logs --project {p} --build {id}` o `/pipeline-logs --project {p} --pipeline {name}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--build {id}` — ID de la build (obligatorio, salvo `--pipeline`)
- `--pipeline {nombre}` — Nombre de pipeline (usa última build)
- `--stage {nombre}` — Filtrar logs de un stage específico
- `--errors-only` — Mostrar solo errores y warnings
- `--tail {n}` — Últimas N líneas de cada step (defecto: 50)

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
2. `.claude/skills/azure-pipelines/SKILL.md` — MCP tools

## 4. Pasos de ejecución

1. **Resolver build:**
   - Si `--build {id}` → usar directamente
   - Si `--pipeline {name}` → MCP `get_builds` top=1 → última build
2. **Obtener status** — MCP `get_build_status`:
   - Estado global, duración, resultado
   - Timeline: stages → jobs → steps
3. **Obtener logs** — MCP `get_build_logs`:
   - Para cada step relevante (o filtrado por `--stage`)
   - Extraer errores (líneas con `##[error]`)
   - Extraer warnings (`##[warning]`)
4. **Presentar resumen:**

```
## Build #143 — backend-ci — FAILED (12m 34s)

Branch: main | Trigger: CI | Started: 2026-02-27 10:15

### Timeline
| Stage | Job | Status | Duración |
|---|---|---|---|
| Build | BuildJob | succeeded | 3m 12s |
| Test | UnitTests | failed | 8m 55s |
| Deploy DEV | — | skipped | — |

### Errores (2)
1. [Test/UnitTests] Step "Run tests":
   `FAIL: AuthServiceTest.TestOAuthFlow — Expected 200, got 401`
2. [Test/UnitTests] Step "Run tests":
   `FAIL: AuthServiceTest.TestRefreshToken — Timeout after 30s`

### Warnings (1)
- [Build/BuildJob] Step "Restore packages":
  `Package Newtonsoft.Json 13.0.1 is deprecated`
```

5. **Si `--errors-only`** → mostrar solo secciones de errores y warnings

## 5. Integración

- `/pipeline-run` → re-ejecutar si el fallo es transitorio
- `/pipeline-status` → contexto global del pipeline
- `/sentry-health` → correlacionar errores de build con errores en runtime

## 6. Restricciones

- Solo lectura — no modifica nada
- Logs pueden ser extensos → limitar con `--tail` y `--stage`
- NO mostrar variables secretas que aparezcan en logs (reemplazar con `***`)
