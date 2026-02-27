---
name: pipeline-artifacts
description: >
  Listar y descargar artefactos de una build de Azure Pipelines.
  Soporta filtro por nombre y tipo.
---

# Pipeline Artifacts

**Argumentos:** $ARGUMENTS

> Uso: `/pipeline:artifacts --project {p} --build {id}` o `/pipeline:artifacts --project {p} --pipeline {name}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--build {id}` — ID de la build (obligatorio, salvo `--pipeline`)
- `--pipeline {nombre}` — Nombre de pipeline (usa última build con artefactos)
- `--name {nombre}` — Filtrar por nombre de artefacto
- `--download` — Descargar artefactos a `output/artifacts/`
- `--list-only` — Solo listar, no descargar (defecto)

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Nombre del proyecto en DevOps
2. `.claude/skills/azure-pipelines/SKILL.md` — MCP tools

## Pasos de ejecución

1. **Resolver build:**
   - Si `--build {id}` → usar directamente
   - Si `--pipeline {name}` → MCP `get_builds` con `statusFilter=completed`
     → primera build con artefactos
2. **Listar artefactos** — MCP `list_artifacts`:
   - Nombre, tipo, tamaño, fecha
3. **Presentar listado:**

```
## Artefactos — Build #143 (backend-ci)

| Nombre | Tipo | Tamaño | Fecha |
|---|---|---|---|
| drop | Build | 45.2 MB | 2026-02-27 10:28 |
| test-results | Pipeline | 2.1 MB | 2026-02-27 10:27 |
| coverage-report | Pipeline | 1.5 MB | 2026-02-27 10:27 |
```

4. **Si `--download`:**
   - MCP `download_artifacts` para cada artefacto (o el filtrado)
   - Guardar en `output/artifacts/{proyecto}/{build-id}/{nombre}/`
   - Mostrar rutas de descarga
5. **Si `--list-only`** → solo mostrar tabla

## Integración

- `/pipeline:logs --build {id}` → ver logs de la build
- `/pipeline:status` → contexto del pipeline
- Artefactos de test → correlacionar con `/kpi:dashboard` (coverage)

## Restricciones

- Descarga requiere espacio en disco — advertir si > 100 MB
- NO descargar artefactos de builds de terceros (solo del proyecto)
- Guardar siempre en `output/artifacts/` con estructura organizada
- Artefactos de tipo `drop` pueden contener binarios grandes → confirmar descarga
