---
id: SPEC-051
title: SPEC-051: Session State Machine for Dev Sessions
status: PROPOSED
origin_date: "2026-03-30"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-051: Session State Machine for Dev Sessions

> Status: **DRAFT** | Fecha: 2026-03-30
> Origen: ComposioHQ/agent-orchestrator — 16-status session lifecycle
> Impacto: Visibilidad granular del estado de cada agente en SDD pipeline

---

## Problema

dev-session-locks.md define 5 estados primitivos para slices:
pending, implementing, validating, verified, completed. Pero no modela:

- Estado del PR una vez abierto (ci-failed, review pending, approved)
- Agente bloqueado o sin respuesta (stuck, needs_input)
- Errores irrecuperables vs recuperables (errored vs ci_failed)
- Transiciones validas (hoy cualquier estado puede saltar a cualquier otro)
- Historial de transiciones para debugging

agent-orchestrator modela 16 estados con transiciones explicitas, reset
de contadores en cada transicion, y deteccion automatica de stuck/errored.
pm-workspace necesita esto para cerrar el gap entre "slice completado"
y "PR mergeado", especialmente con el reaction engine (SPEC-050).

---

## Arquitectura

### Estados (13, adaptados de los 16 de AO)

```
spawning → implementing → validating → verified → pr_open
                                                      ↓
                              ┌─────────────────── ci_failed
                              ↓                       ↓ (fix)
                         review_pending ←──────── pr_open
                              ↓
                     changes_requested → implementing (loop)
                              ↓
                          approved → mergeable → merged → done

Estados terminales: done, errored, killed
Estados transversales: stuck (timeout), needs_input (esperando humano)
```

### Transiciones validas

| Desde | Hacia | Trigger |
|-------|-------|---------|
| spawning | implementing | Contexto cargado |
| implementing | validating | Codigo escrito |
| validating | verified | Tests + coherence pasan |
| verified | pr_open | PR creado |
| pr_open | ci_failed | CI rojo |
| pr_open | review_pending | CI verde, awaiting review |
| ci_failed | pr_open | Fix pusheado (via SPEC-050) |
| review_pending | changes_requested | Reviewer pide cambios |
| review_pending | approved | Reviewer aprueba |
| changes_requested | implementing | Agente recibe feedback |
| approved | mergeable | CI verde + aprobado |
| mergeable | merged | Humano mergea (NUNCA auto) |
| merged | done | Cleanup completado |
| * | stuck | Timeout sin actividad |
| * | errored | Error irrecuperable |
| * | killed | Terminado manualmente |

### State file ampliado

```json
{
  "session_id": "20260330-AB102-feature",
  "status": "review_pending",
  "previous_status": "pr_open",
  "status_changed_at": "2026-03-30T10:15:00Z",
  "pr": { "number": 42, "url": "...", "ci_status": "passing" },
  "reaction_retries": { "ci-failed": 0, "changes-requested": 0 },
  "transitions": [
    { "from": "spawning", "to": "implementing", "at": "...", "trigger": "context_loaded" },
    { "from": "implementing", "to": "pr_open", "at": "...", "trigger": "pr_created" }
  ]
}
```

---

## Integracion

### Con dev-session-locks.md

Reemplaza los 5 estados de slice por los 13 estados de sesion.
Los locks siguen existiendo para crash recovery (PID detection).
El state file se enriquece con status, transitions, pr info.

### Con SPEC-050 (Reaction Engine)

El reaction engine actualiza el status basandose en eventos detectados.
ci_failed y changes_requested activan reacciones configuradas.
El reset de reaction_retries ocurre en cada transicion de estado.

### Con agent-trace-log.sh

Cada transicion de estado genera un evento de traza:
`{ "event": "state_transition", "from": "pr_open", "to": "ci_failed" }`.
Permite reconstruir la timeline completa de una dev-session.

### Con /savia-live (SPEC-042)

`/savia-live` puede mostrar el estado actual de cada sesion activa
con los 13 estados y sus transiciones recientes.

---

## Restricciones

- Transiciones fuera del grafo definido → error + log (no silenciar)
- Maximo 10 transiciones ci_failed→pr_open antes de escalar (loop guard)
- Estado `mergeable` NO auto-mergea (autonomous-safety.md)
- El historial de transiciones se limita a 50 entries (luego rotar)
- Compatible hacia atras: sesiones con formato antiguo se migran a `implementing`

---

## Implementacion por fases

### Fase 1 — State machine core (~1.5h)
- [ ] Definir transiciones validas en regla de dominio
- [ ] Modificar state.json: status, transitions, pr. Test: transicion invalida → error

### Fase 2 — Integracion PR lifecycle (~1.5h)
- [ ] Detectar PR creado por agente, transicionar a pr_open
- [ ] Detectar CI status y review status. Test: flujo completo spawn→merged

### Fase 3 — Observabilidad (~1h)
- [ ] Emitir eventos de traza por transicion
- [ ] Loop guard (max ci_failed retries). Integracion con /savia-live

---

## Ficheros afectados

| Fichero | Accion |
|---------|--------|
| `docs/rules/domain/session-state-machine.md` | Crear — grafo de transiciones |
| `docs/rules/domain/dev-session-locks.md` | Modificar — ampliar state.json |
| `.claude/hooks/agent-trace-log.sh` | Modificar — emitir state transitions |

---

## Metricas de exito

- Estados cubiertos: 13/13 detectados automaticamente
- Transiciones invalidas en produccion: 0 (grafo es exhaustivo)
- Tiempo en estado stuck antes de deteccion: <5min
- Historial de transiciones disponible para debugging: 100% sesiones
