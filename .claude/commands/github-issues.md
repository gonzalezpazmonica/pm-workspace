---
name: github-issues
description: >
  Gestionar issues de GitHub: buscar, crear desde PBIs, sincronizar
  con Azure DevOps work items.
---

# Issues GitHub

**Argumentos:** $ARGUMENTS

> Uso: `/github:issues {repo} [--sync-from-azdo {ids}] [--search {query}] [--create {titulo}]`

## Parámetros

- `{repo}` — Repositorio en formato `org/repo`
- `--project {nombre}` — Usar repo de `projects/{p}/CLAUDE.md`
- `--search {query}` — Buscar issues por texto, labels o milestone
- `--open` / `--closed` — Filtrar por estado
- `--sync-from-azdo {pbi_ids}` — Crear issues desde PBIs de Azure DevOps (bidireccional)
- `--sync-to-azdo` — Crear PBIs en Azure DevOps desde issues de GitHub abiertos
- `--label {label}` — Filtrar por label
- `--link {issue_id} {pbi_id}` — Vincular issue de GitHub con PBI de Azure DevOps

## Contexto requerido

1. `.claude/rules/connectors-config.md` — Verificar conector GitHub
2. `projects/{proyecto}/CLAUDE.md` — Repo y proyecto Azure DevOps
3. `.claude/rules/pm-config.md` — Config Azure DevOps para sync

## Pasos de ejecución

### Modo búsqueda (`--search`)

1. Buscar issues en el repo via conector GitHub
2. Mostrar resultados con: número, título, labels, asignado, fecha

### Modo sync Azure DevOps → GitHub (`--sync-from-azdo`)

1. Leer PBIs de Azure DevOps por IDs
2. Para cada PBI → crear issue en GitHub:
   - Título: `[AB#{id}] {titulo_pbi}`
   - Body: descripción + criterios de aceptación
   - Labels: mapeados desde tags del PBI
   - Milestone: nombre del sprint si existe
3. Añadir comentario en el PBI de Azure DevOps con link al issue
4. Mostrar tabla de mapeo:
   ```
   ✅ Issues creados en GitHub

   ┌───────────┬────────────┬──────────────────────────────┐
   │ PBI AzDO  │ Issue GH   │ Título                       │
   ├───────────┼────────────┼──────────────────────────────┤
   │ AB#1234   │ #45        │ Implementar auth endpoint    │
   │ AB#1235   │ #46        │ Schema base de datos users   │
   └───────────┴────────────┴──────────────────────────────┘
   ```

### Modo sync GitHub → Azure DevOps (`--sync-to-azdo`)

1. Listar issues abiertos sin link a PBI
2. Para cada issue → proponer creación de PBI:
   - Mapear labels → tags Azure DevOps
   - Estimar SP si hay suficiente contexto
3. Confirmar con el PM antes de crear
4. Actualizar issue con link al PBI creado

### Modo link (`--link`)

1. Añadir comentario en issue de GitHub: `Linked to Azure DevOps: AB#{pbi_id}`
2. Añadir comentario en PBI de Azure DevOps: `Linked to GitHub: {repo}#{issue_id}`
3. Confirmar vinculación

## Mapeo de campos

| GitHub Issue | Azure DevOps PBI |
|---|---|
| Title | Title (prefijado con [AB#id]) |
| Body | Description |
| Labels | Tags |
| Milestone | Iteration Path |
| Assignees | Assigned To (requiere mapeo en equipo.md) |
| State (open/closed) | State (New/Active/Closed) |

## Restricciones

- **Confirmar antes de crear** issues o PBIs — nunca crear sin aprobación
- No duplicar: verificar que no exista ya un issue/PBI vinculado
- Máximo 20 sync por ejecución (protección contra errores masivos)
- Si el mapeo de usuario falla → dejar sin asignar y avisar
