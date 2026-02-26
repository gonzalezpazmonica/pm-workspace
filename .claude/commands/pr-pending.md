---
name: pr-pending
description: >
  Consulta los Pull Requests asignados al PM que están pendientes de revisión
  en Azure DevOps. Muestra estado, votos, comentarios pendientes y antigüedad.
---

# Pull Requests Pendientes de Revisión

**Filtro:** $ARGUMENTS

> Uso: `/pr:pending` (todos los proyectos) · `/pr:pending --project Alpha` (un proyecto)

---

## Protocolo

### 1. Leer configuración

Obtener de `CLAUDE.md` o `pm-config.md`:
- `AZURE_DEVOPS_ORG_URL` — URL de la organización
- `AZURE_DEVOPS_PAT_FILE` — fichero con el PAT
- `AZURE_DEVOPS_PM_USER` — email/uniqueName del PM

Si `AZURE_DEVOPS_PM_USER` no está definido, preguntar al usuario y sugerir que lo añada a la configuración.

### 2. Obtener proyectos

- Si se pasa `--project`, usar solo ese proyecto
- Si no, leer los proyectos activos de `CLAUDE.md` y `CLAUDE.local.md`

### 3. Consultar PRs por proyecto

Para cada proyecto, ejecutar:

```bash
curl -s -u ":$(cat $AZURE_DEVOPS_PAT_FILE)" \
  "$AZURE_DEVOPS_ORG_URL/$PROJECT/_apis/git/pullrequests?searchCriteria.reviewerId=$PM_USER_ID&searchCriteria.status=active&api-version=7.1"
```

**Nota:** La API de PRs filtra por `reviewerId` (GUID), no por email. Primero resolver el ID:

```bash
curl -s -u ":$(cat $AZURE_DEVOPS_PAT_FILE)" \
  "$AZURE_DEVOPS_ORG_URL/_apis/identities?searchFilter=General&filterValue=$AZURE_DEVOPS_PM_USER&api-version=7.1"
```

### 4. Filtrar PRs con reviewer-asignado pendiente

Antes de mostrar un PR al PM, comprobar si el PR tiene **más de un reviewer** y uno de ellos es el **programador asignado a la tarea de DevOps** que originó el cambio (extraer task ID del nombre de rama `feature/#XXXX-...` o `fix/#XXXX-...` → consultar `System.AssignedTo` de esa task).

- Si el programador asignado **aún no ha votado** (vote = 0) → **ocultar el PR** de la lista del PM. El PM no necesita revisarlo hasta que el propio programador lo valide primero.
- Si el programador asignado **ya votó** (vote ≠ 0, cualquier valor) → mostrar el PR normalmente al PM.
- Si el PR **no tiene task ID** en la rama, o la task **no tiene asignado**, o el PR **solo tiene un reviewer** → mostrar normalmente (sin filtro).

### 5. Para cada PR visible, obtener detalle

Por cada PR activo donde el PM es reviewer (y que haya pasado el filtro del paso 4):

```bash
# Threads (comentarios) del PR
curl -s -u ":$(cat $AZURE_DEVOPS_PAT_FILE)" \
  "$AZURE_DEVOPS_ORG_URL/$PROJECT/_apis/git/repositories/$REPO_ID/pullRequests/$PR_ID/threads?api-version=7.1"
```

Extraer:
- **Estado del voto del PM**: `reviewers[].vote` → 10=Aprobado, 5=Aprobado con sugerencias, 0=Sin voto, -5=Esperando, -10=Rechazado
- **Comentarios activos**: threads con `status=active` (no resueltos)
- **Comentarios del PM pendientes de respuesta**: threads creados por PM donde la última respuesta no es del autor del PR
- **Antigüedad**: `creationDate` → días desde creación

### 6. Presentar resultado

```
══════════════════════════════════════════════════════
  PULL REQUESTS PENDIENTES · {PM_DISPLAY_NAME}
══════════════════════════════════════════════════════

  📊 Resumen: {total} PRs pendientes en {n} proyectos

  ─── Proyecto Alpha ───

  PR #1234 · feat: add user registration
    Autor:     Laura Sánchez
    Rama:      feature/user-registration → main
    Creado:    2026-02-20 (hace 6 días) ⚠️
    Mi voto:   🔵 Sin votar
    Hilos:     3 activos (1 mío sin respuesta)
    Tamaño:    +245 / -18 (12 archivos)

  PR #1267 · fix: session timeout handling
    Autor:     Carlos Mendoza
    Rama:      fix/session-timeout → main
    Creado:    2026-02-25 (hace 1 día)
    Mi voto:   🟡 Esperando autor
    Hilos:     1 activo (esperando respuesta del autor)
    Tamaño:    +32 / -8 (3 archivos)

  ─── Proyecto Beta ───

  (sin PRs pendientes)

══════════════════════════════════════════════════════

  ⚠️  2 PRs llevan > 3 días sin revisar
  💬  1 comentario tuyo sin respuesta del autor

══════════════════════════════════════════════════════
```

### 7. Alertas

Generar alertas cuando:
- Un PR lleva **> 3 días** sin voto del PM → ⚠️ alerta de antigüedad
- Un PR tiene **comentarios del PM sin respuesta** del autor → 💬 seguimiento
- Un PR tiene **0 reviewers con voto** → 🔴 bloqueado
- Un PR tiene **conflictos de merge** → ⛔ requiere acción del autor
- Hay PRs **ocultos por validación pendiente del programador asignado** → 🕐 informar cuántos PRs están esperando revisión del dev asignado (sin listar detalle, solo contador)

---

## Restricciones

- **Solo lectura** — este comando no modifica ni aprueba PRs
- **Solo PRs donde el PM es reviewer** — no lista todos los PRs del proyecto
- Si el PAT no tiene scope `Code (Read)`, informar al usuario
- Si `AZURE_DEVOPS_PM_USER` no está configurado, bloquear y pedir configuración
