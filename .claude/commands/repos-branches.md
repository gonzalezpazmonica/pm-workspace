---
name: repos-branches
description: >
  Gestión de branches en Azure Repos: listar, crear, comparar
  y verificar políticas de branch.
---

# Repos Branches

**Argumentos:** $ARGUMENTS

> Uso: `/repos-branches --project {p} --repo {r}` o `/repos-branches --project {p} --repo {r} --create {name}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--repo {nombre}` — Repositorio (obligatorio, o usa `AZURE_REPOS_DEFAULT_REPO`)
- `--create {nombre}` — Crear nueva branch (formato: `feature/#XXXX-desc`)
- `--from {ref}` — Branch origen para `--create` (defecto: main)
- `--compare {branch1} {branch2}` — Comparar dos branches
- `--active-only` — Solo branches con actividad reciente (< 30 días)

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — `AZURE_REPOS_PROJECT`, `AZURE_REPOS_DEFAULT_REPO`
2. @.claude/rules/domain/azure-repos-config.md — Convenciones de naming

## Pasos de ejecución

### Listar branches
1. **MCP `list_branches`** → branches del repo
2. **Clasificar:**
   - Activas (commit < 30d)
   - Stale (commit > 30d)
   - Ahead/behind respecto a main
3. **Presentar:**

```
## Branches — {repo}

| Branch | Último commit | Ahead/Behind | Autor |
|---|---|---|---|
| main | hace 2h | — | — |
| feature/#1234-auth | hace 1d | +5 / -0 | Ana García |
| fix/#1235-login | hace 3d | +2 / -3 | Pedro López |
| (stale) old-feature | hace 45d | +12 / -28 | — |
```

### Crear branch
1. **Validar naming** contra patrón `BRANCH_PATTERN`
2. **Verificar** que no existe ya
3. **MCP `create_branch`** desde `--from`
4. **Confirmar** creación con link

## Restricciones

- Crear branch requiere confirmación del PM (regla 3)
- Branch naming debe seguir convención: `feature/#XXXX-desc` o `fix/#XXXX-desc`
- No eliminar branches — solo listar y crear
