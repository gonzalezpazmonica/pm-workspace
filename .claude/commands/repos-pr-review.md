---
name: repos-pr-review
description: >
  Review multi-perspectiva de un PR en Azure Repos. Analiza
  desde BA, Dev, QA, Security y DevOps (reutiliza patrón pr:review).
---

# Repos PR Review

**Argumentos:** $ARGUMENTS

> Uso: `/repos:pr-review --project {p} --pr {id}` o `/repos:pr-review --project {p} --repo {r} --pr {id}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--repo {nombre}` — Repositorio (obligatorio o `AZURE_REPOS_DEFAULT_REPO`)
- `--pr {id}` — ID del Pull Request (obligatorio)
- `--perspective {tipo}` — Perspectiva específica: `ba`, `dev`, `qa`, `security`, `devops`, `all` (defecto: all)
- `--add-comments` — Añadir comentarios al PR en Azure Repos (requiere confirmación)

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto y repo
2. `projects/{proyecto}/reglas-negocio.md` — Para perspectiva BA
3. @.claude/rules/domain/azure-repos-config.md — Políticas de branch

## Pasos de ejecución

1. **Obtener PR** — MCP `list_pull_requests` + filtrar por ID
2. **Obtener diff** — Obtener cambios del PR (files changed)
3. **Obtener comentarios existentes** — MCP `get_pull_request_comments`
4. **Analizar desde cada perspectiva:**

### Business Analyst
- ¿Los cambios implementan lo descrito en los work items vinculados?
- ¿Se respetan las reglas de negocio del proyecto?
- ¿Faltan criterios de aceptación por cubrir?

### Developer
- Calidad del código: naming, SOLID, DRY, complejidad
- Patrones del proyecto respetados
- Gestión de errores y edge cases

### QA / Test Engineer
- ¿Hay tests nuevos para el código nuevo?
- ¿Coverage estimado se mantiene >= 80%?
- ¿Hay tests de integración si aplica?

### Security
- Secrets hardcodeados, SQL injection, XSS
- Dependencias con vulnerabilidades conocidas
- Autenticación y autorización correctas

### DevOps
- ¿El cambio afecta a la pipeline?
- ¿Hay migraciones de DB?
- ¿Requiere cambios en infra/config?

5. **Presentar informe** estructurado por perspectiva
6. **Si `--add-comments`:**
   - Confirmar con PM antes de publicar
   - MCP `create_pr_comment` para cada hallazgo relevante

## Integración

- `/repos:pr-list` → contexto de PRs activos
- `/pipeline:logs` → si la build falla
- `/pr:review` → equivalente para PRs de GitHub

## Restricciones

- Añadir comentarios al PR requiere confirmación del PM
- No aprobar/rechazar el PR automáticamente — eso es decisión humana
- Si el diff es muy grande (>500 ficheros) → advertir y sugerir scope
