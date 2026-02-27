---
name: repos-pr-create
description: >
  Crear Pull Request en Azure Repos con linking automático
  a work items, asignación de reviewers y auto-complete.
---

# Repos PR Create

**Argumentos:** $ARGUMENTS

> Uso: `/repos:pr-create --project {p} --repo {r}` o con todos los params

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--repo {nombre}` — Repositorio (obligatorio o `AZURE_REPOS_DEFAULT_REPO`)
- `--source {branch}` — Rama source (obligatorio)
- `--target {branch}` — Rama target (defecto: main)
- `--title {título}` — Título del PR (o inferir de commits)
- `--description {desc}` — Descripción (o generar desde commits)
- `--work-items {ids}` — IDs de work items a vincular (AB#1234,AB#1235)
- `--reviewers {emails}` — Reviewers (o asignar desde equipo.md)
- `--auto-complete` — Activar auto-complete tras aprobaciones
- `--draft` — Crear como draft PR

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del repo
2. `projects/{proyecto}/equipo.md` — Reviewers disponibles
3. @.claude/rules/domain/azure-repos-config.md — Políticas y convenciones

## Pasos de ejecución

1. **Resolver repo y branches**
2. **Verificar PR duplicado** — MCP `list_pull_requests` filtrando por source
   - Si existe → informar y mostrar link
3. **Inferir datos si no se proporcionan:**
   - Título: del patrón `[AB#XXXX] Descripción` o del último commit
   - Descripción: resumen de commits entre source y target
   - Work items: extraer `AB#XXXX` de commits
   - Reviewers: del equipo.md (tech lead + 1 developer)
4. **Presentar propuesta:**

```
## Nuevo PR — {repo}

- Source: feature/#1234-auth-oauth
- Target: main
- Título: [AB#1234] Implementar OAuth 2.0
- Work items: AB#1234, AB#1235
- Reviewers: Ana García, Pedro López
- Auto-complete: Sí
- Draft: No

### Commits incluidos (3):
- feat: add OAuth provider configuration
- feat: implement token refresh flow
- test: add OAuth integration tests

¿Crear PR? (S/N)
```

5. **CONFIRMAR con PM** → NUNCA crear sin confirmación
6. **MCP `create_pull_request`** con todos los datos
7. **Si `--auto-complete`** → MCP `update_pull_request` con auto-complete
8. **Resultado:** link al PR creado

## Integración

- `/repos:pr-list` → ver PRs del repo
- `/repos:pr-review` → review multi-perspectiva del PR
- `/pipeline:status` → verificar que la build de validación pasa

## Restricciones

- **NUNCA crear PR sin confirmación** del PM
- Validar naming del título según `PR_TITLE_PATTERN`
- Si no hay work items vinculados → warning (política lo recomienda)
- Si la build de validación falla → advertir antes de crear
