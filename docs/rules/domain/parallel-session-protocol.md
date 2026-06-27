---
context_tier: L2
token_budget: 600
---

# Parallel Session Protocol (SE-229)

> Prevents branch conflicts when multiple Savia sessions run simultaneously
> in different terminals or nidos.

## Regla: toda sesión autónoma DEBE registrarse antes de git ops

Antes de cualquier operación git (checkout, commit, push, worktree add), toda
sesión autónoma (overnight-sprint, code-improvement-loop, nido activo) DEBE:

1. Generar un session_id: `${PPID}-$(date +%s)` si `$CLAUDE_SESSION_ID` no está set.
2. Registrar la sesión:
   ```bash
   bash scripts/session-registry.sh register \
     --session "$SESSION_ID" \
     --nido    "$SAVIA_NIDO" \
     --branch  "$BRANCH" \
     --task    "descripción breve"
   ```
3. Reclamar la rama antes de usarla:
   ```bash
   bash scripts/session-registry.sh claim \
     --branch "$BRANCH" --session "$SESSION_ID"
   # exit 1 → rama ocupada → abortar o elegir otra rama
   ```
4. Hacer release al terminar o en el hook Stop:
   ```bash
   bash scripts/session-registry.sh release --session "$SESSION_ID"
   ```

Incumplir este protocolo no bloquea el trabajo pero elimina la protección
anti-conflicto. El hook `session-init.sh` lo hace automáticamente cuando
`SAVIA_NIDO` está set.

## Coordinación cuando dos sesiones quieren la misma rama

`claim` devuelve exit 0 (rama libre) o exit 1 + WARNING (rama ocupada).

```
Session A: claim --branch feature/X --session A  → exit 0  (A registrada)
Session B: claim --branch feature/X --session B  → exit 1  WARNING: branch 'feature/X' is already claimed by session 'A'
```

Session B ante exit 1 debe:
- Opción 1: Esperar a que Session A haga release (verificar con `list`).
- Opción 2: Crear rama derivada: `feature/X-session-B`.
- Opción 3 (emergencia): ignorar el warning si se sabe que Session A ya terminó
  pero no hizo release (e.g. crash). Luego ejecutar `gc` para limpiar.

Una sesión NO puede reclamar la rama de otra sesión activa. Solo puede
reclamar su propia rama (idempotente).

## Cómo leer el registro de sesiones activas

```bash
# Ver tabla de sesiones activas (heartbeat <10 min)
bash scripts/session-registry.sh list

# Ver el JSONL crudo
cat ~/.savia/active-sessions.jsonl

# Filtrar por rama (requiere jq o grep)
grep '"branch":"feature/X"' ~/.savia/active-sessions.jsonl
```

Campos del JSONL:
- `session_id` — identificador único de sesión
- `pid` — PID del proceso al registrar
- `nido` — nombre del nido (vacío si sesión manual)
- `branch` — rama git reclamada
- `task` — descripción breve de la tarea
- `worktree` — path del worktree (opcional)
- `started_at` — ISO-8601 UTC de inicio
- `heartbeat_at` — ISO-8601 UTC del último heartbeat
- `status` — `active` | `released`

Sesiones con `heartbeat_at` >10 min se consideran stale y `list` no las muestra.
`gc` las elimina del fichero.

## Cómo hacer release al terminar

El hook `session-end-snapshot.sh` llama a `release` y `gc` automáticamente si
`SAVIA_SESSION_ID` está set. Para sesiones manuales:

```bash
bash scripts/session-registry.sh release --session "$SESSION_ID"
bash scripts/session-registry.sh gc
```

Puedes forzar la limpieza de sesiones stale sin conocer el session_id:

```bash
bash scripts/session-registry.sh gc
```

`gc` elimina entradas con heartbeat >10 min y entradas con status=released.

## Notas de implementación

- `~/.savia/active-sessions.jsonl` es local, nunca commiteado (gitignored).
- `flock` protege todas las escrituras — seguro para escrituras concurrentes.
- Dependencia `jq` es opcional; fallback a `python3` disponible siempre.
- El lock file es `~/.savia/active-sessions.lock`.
