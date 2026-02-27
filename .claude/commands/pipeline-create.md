---
name: pipeline-create
description: >
  Crear una nueva pipeline en Azure Pipelines desde template YAML.
  Preview y confirmación antes de crear.
---

# Pipeline Create

**Argumentos:** $ARGUMENTS

> Uso: `/pipeline:create --project {p} --name {n} --repo {r}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--name {nombre}` — Nombre de la pipeline (obligatorio)
- `--repo {nombre}` — Repositorio que contiene el YAML (obligatorio)
- `--yaml-path {path}` — Ruta al fichero YAML (defecto: `azure-pipelines.yml`)
- `--template {tipo}` — Template base: `build-test`, `multi-env`, `pr-validation`, `nightly`
- `--language {lang}` — Lenguaje del proyecto (para adaptar template)
- `--branch {rama}` — Rama por defecto (defecto: main)

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Nombre del proyecto en DevOps, Language Pack
2. `.claude/skills/azure-pipelines/SKILL.md` — Templates y patrones
3. Skill `azure-pipelines` → `yaml-templates.md` — Templates YAML

## Pasos de ejecución

1. **Seleccionar template** según `--template` o inferir del proyecto:
   - Si tiene entornos (DEV/PRE/PRO) → `multi-env`
   - Si es librería/package → `build-test`
   - Si solo validación de PRs → `pr-validation`
2. **Adaptar template** al lenguaje del proyecto:
   - Leer Language Pack del proyecto
   - Ajustar: SDK version, build command, test command, publish
3. **Generar YAML** adaptado y presentar al PM:

```
## Nueva Pipeline — {nombre}

Template: multi-env ({language})
Repo: {repo} (branch: main)
YAML path: azure-pipelines.yml

### YAML generado:
(mostrar YAML completo)

### Stages:
1. Build → dotnet build
2. Test → dotnet test (coverage >= 80%)
3. Deploy DEV → auto
4. Deploy PRE → approval: tech-lead
5. Deploy PRO → approval: PM + PO
```

4. **Confirmar con PM:**
   - ¿Crear pipeline con este YAML?
   - ¿Necesita variables adicionales?
   - ¿Ajustar triggers?
5. **Preview** — MCP `preview_pipeline_run` para validar YAML
6. **Crear** — MCP `create_pipeline`:
   - Nombre, repositorio, YAML path, branch
7. **Resultado:** link a la pipeline creada en Azure DevOps

## Restricciones

- **NUNCA crear sin confirmación** del PM
- El YAML se genera como propuesta — el PM puede editar
- No configurar approval gates automáticamente (eso requiere Azure DevOps UI)
- Si el repo no existe en Azure Repos → informar y sugerir crearlo
- Sugerir crear también la pipeline de PR Validation junto a la principal

## Integración

- `/pipeline:status` → verificar que la pipeline aparece
- `/pipeline:run` → ejecutar primera build
- `/env:setup` → configurar entornos si no existen
