# SPEC-048: Dev Session Discard

> Status: **DRAFT** | Fecha: 2026-03-30
> Origen: garagon/nanostack research — explicit "invalidate bad run" pattern
> Impacto: Limpieza segura de sesiones fallidas sin dejar artefactos huerfanos

---

## Problema

`/dev-session` tiene mecanismos para start, next, resume y review, pero
carece de un abort/discard limpio. Cuando una sesion va mal (spec incorrecto,
approach equivocado, crash irrecuperable), el unico recurso es:

1. Abandonar la sesion y dejar artefactos huerfanos en disco
2. Limpiar manualmente lock files, state files y worktrees
3. Esperar 24h a que la limpieza automatica elimine el lock stale

Consecuencias:
- Locks huerfanos que confunden a `/dev-session resume`
- Ficheros parciales en `output/dev-sessions/{id}/` sin contexto
- Worktrees de git abandonados consumiendo disco
- Sin registro de POR QUE se descarto (se pierde el aprendizaje)

---

## Arquitectura

### Comando: /dev-session discard

```
/dev-session discard [session-id] [--reason "texto"]
```

Si `session-id` se omite, usa la sesion activa (del lock actual).

### Pipeline de discard (5 pasos)

1. VALIDAR — sesion existe (lock o state file)
2. REGISTRAR — razon + estado final en discard-log
3. LIMPIAR LOCK — eliminar .claude/sessions/{id}.lock
4. LIMPIAR WORKTREE — git worktree remove si existe
5. ARCHIVAR STATE — mover state.json a discarded/

### Discard Log

Fichero: `output/dev-sessions/discard-log.jsonl` (append-only)

```json
{
  "session_id": "20260330-AB105-auth",
  "discarded_at": "2026-03-30T14:30:00Z",
  "reason": "Spec incorrecto — no incluia requisito de 2FA",
  "state_at_discard": "implementing",
  "slices_completed": 2,
  "slices_total": 5,
  "files_affected": ["AuthService.cs", "AuthController.cs"],
  "spec_path": "specs/AB105-auth.spec.md"
}
```

---

## Integracion

### Con dev-session-protocol.md

Nuevo estado en el diagrama de transiciones:

```
pending → implementing → validating → verified → completed
                |                         |
                +------→ discarded ←------+
```

Cualquier estado excepto `completed` puede transicionar a `discarded`.
Un slice `completed` ya fue integrado — no se puede descartar sin revert.

### Con dev-session-locks.md

El discard elimina el lock file del mismo modo que la finalizacion normal.
La diferencia: el state.json se mueve a `discarded/` en lugar de eliminarse.

Si el lock es stale (PID muerto + >30 min), `/dev-session discard` funciona
igual — no requiere que el proceso original este vivo.

### Con commit-guardian y self-improvement

CHECK 11 warning desaparece tras discard (lock eliminado). Si `--reason`
menciona error de spec, Savia sugiere registrar en tasks/lessons.md.

---

## UX del comando

Banner muestra: sesion activa, estado, slices completados, ficheros tocados.
Pide razon interactivamente. Confirma cada paso del pipeline con checkmarks.
Si motivo menciona spec incorrecto, sugiere registrar en tasks/lessons.md.

### Flags

| Flag | Efecto |
|------|--------|
| `--reason "texto"` | Razon sin pregunta interactiva |
| `--force` | Descartar sin confirmacion (para scripts) |
| `--keep-files` | No eliminar worktree (para inspeccion manual) |

---

## Restricciones

- NUNCA descartar una sesion con slices en estado `completed` sin
  confirmacion explicita (los ficheros ya fueron integrados)
- NUNCA eliminar ficheros fuera de `output/dev-sessions/` y `.claude/sessions/`
- El discard-log es append-only — NUNCA borrar entradas
- La razon es obligatoria (interactiva o por flag)
- El discard NO revierte commits ya hechos — solo limpia estado de sesion

---

## Implementacion por fases

### Fase 1 — Comando basico (~1h)
- [ ] Crear `.claude/commands/dev-session-discard.md` (o extender dev-session.md)
- [ ] Implementar pipeline de 5 pasos en el flujo del comando
- [ ] Crear discard-log.jsonl con formato definido
- [ ] Test: discard de sesion activa + discard de sesion stale

### Fase 2 — Integracion (~30min)
- [ ] Actualizar dev-session-locks.md con estado `discarded`
- [ ] Actualizar dev-session-protocol.md con transicion a discarded
- [ ] Integrar sugerencia de lessons.md

### Fase 3 — Metricas
- [ ] `/dev-session stats` muestra ratio completadas/descartadas
- [ ] Razones mas frecuentes de descarte (para mejorar specs)

---

## Ficheros afectados

| Fichero | Accion |
|---------|--------|
| `.claude/commands/dev-session.md` | Modificar — anadir subcomando discard |
| `.claude/rules/domain/dev-session-protocol.md` | Modificar — estado discarded |
| `.claude/rules/domain/dev-session-locks.md` | Modificar — transicion discarded |
| `output/dev-sessions/discard-log.jsonl` | Nuevo (runtime, gitignored) |
