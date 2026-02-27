---
name: repos-pr-list
description: >
  Listar Pull Requests en Azure Repos: pendientes, asignados
  al PM, por reviewer, con estado de builds y votos.
---

# Repos PR List

**Argumentos:** $ARGUMENTS

> Uso: `/repos:pr-list --project {p}` o `/repos:pr-list --project {p} --repo {r} --status {s}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--repo {nombre}` — Repositorio específico (opcional, si no: todos)
- `--status {estado}` — Filtro: `active`, `completed`, `abandoned`, `all` (defecto: active)
- `--assigned-to-me` — Solo PRs donde el PM es reviewer
- `--created-by {email}` — Filtrar por creador
- `--last {n}` — Últimos N PRs (defecto: 20)

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — `AZURE_REPOS_PROJECT`
2. @.claude/rules/domain/pm-config.md — `AZURE_DEVOPS_PM_USER` (para --assigned-to-me)

## Pasos de ejecución

1. **Resolver proyecto y repos**
2. **MCP `list_pull_requests`** con filtros aplicados
3. **Para cada PR:**
   - ID, título, autor, fecha de creación
   - Source → target branch
   - Estado de votos (approve, reject, wait)
   - Estado de build (si hay pipeline de validación)
   - Work items vinculados
   - Antigüedad (días desde creación)
4. **Presentar tabla:**

```
## Pull Requests — {proyecto} (active)

| PR | Título | Autor | Branch | Votos | Build | Edad |
|---|---|---|---|---|---|---|
| #42 | [AB#1234] OAuth 2.0 | Ana | feature/#1234 → main | 1/2 ✅ | passed | 2d |
| #41 | [AB#1230] Fix login | Pedro | fix/#1230 → main | 0/2 | failed | 3d |
| #39 | [AB#1228] Refactor DB | Ana | feature/#1228 → main | 2/2 ✅ | passed | 5d |

### Resumen
- 3 PRs activos, 1 listo para merge (#39)
- 1 build fallida (#41) — revisar con `/repos:pr-review`
- Antigüedad media: 3.3 días
```

## Integración

- `/repos:pr-review --pr {id}` → review detallado
- `/pr:pending` → similar pero para GitHub (equivalente Azure Repos)
- `/pipeline:logs` → si build fallida, ver logs

## Restricciones

- Solo lectura
- Máximo 50 PRs por consulta
- Si `--assigned-to-me` y no hay PM configurado → error con sugerencia
