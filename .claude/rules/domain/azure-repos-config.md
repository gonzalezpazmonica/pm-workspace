# Regla: Configuración Azure Repos

> Configuración para gestión de repositorios Git en Azure DevOps.
> Carga bajo demanda cuando se usan comandos `repos-*`.

## Proveedor Git por proyecto

```
# En projects/{p}/CLAUDE.md — elegir proveedor
GIT_PROVIDER                = "github"              # github | azure-repos
AZURE_REPOS_PROJECT         = "NombreProyectoDevOps"
AZURE_REPOS_DEFAULT_REPO    = "backend-api"         # repo por defecto
AZURE_REPOS_DEFAULT_BRANCH  = "main"                # rama principal
```

## Convenciones de branches (consistente con pm-workflow.md)

```
BRANCH_FEATURE_PREFIX       = "feature/"
BRANCH_FIX_PREFIX           = "fix/"
BRANCH_PATTERN              = "{prefix}#XXXX-descripcion"
PR_TITLE_PATTERN            = "[AB#XXXX] Descripción corta"
```

## Políticas de rama recomendadas

| Política | main | develop |
|---|---|---|
| Reviewers mínimos | 2 | 1 |
| Build validation | Sí (pipeline PR) | Sí |
| Work item linking | Obligatorio | Recomendado |
| Comment resolution | Todos resueltos | Todos resueltos |
| Merge strategy | Squash | Squash |

## PAT Scopes requeridos

```
Code (Read & Write)  — para crear branches, PRs, comments
```

## MCP tools de Azure Repos

- `list_repositories` — listar repos del proyecto
- `get_repository` — detalles de un repo
- `list_branches` — branches de un repo
- `create_branch` — crear branch desde ref
- `list_pull_requests` — PRs del repo (filtro: status, creator, reviewer)
- `create_pull_request` — crear PR con title, description, reviewers
- `update_pull_request` — actualizar PR (status, auto-complete)
- `get_pull_request_comments` — comentarios de un PR
- `create_pr_comment` — añadir comentario a PR
- `search_code` — buscar código en repos del proyecto
