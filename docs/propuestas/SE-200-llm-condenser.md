---
spec_id: SE-200
title: LLM Condenser — rolling window context compression
status: APPROVED
tier: 1
priority: P1
effort: M
era: 200
wave: 1
deps: []
unblocks:
  - SE-201
origin: output/research/openhands-savia-20260607.md
inspiration: OpenHands context-condenser pattern (rolling window + episodic memory)
---

# SE-200 — LLM Condenser — rolling window context compression

> Estado: APPROVED · Tier 1 · P1 · Estimación M · Era 200 · Wave 1

## Resumen

Hook PostTurn que comprime el historial de contexto cuando supera `max_size=120` eventos. Usa Haiku como modelo secundario. Preserva head (4 primeros) + tail (60 últimos); comprime el medio en una `Condensation` entry escrita en la memoria episódica. Evita context overflow silencioso que degrada la calidad de respuesta en sesiones largas.

## Motivación

- Sesiones largas de pm-workspace pueden superar el context window sin señal visible al usuario.
- OpenHands resuelve esto con un condenser LLM que produce un resumen estructurado del segmento medio.
- El patrón head+tail preserva el intent original (head) y el estado reciente (tail) — los más críticos para continuidad.
- Haiku como modelo secundario mantiene coste bajo: la condensación es una tarea de resumen, no de razonamiento profundo.
- La `Condensation` entry en memoria episódica permite auditar qué se comprimió y cuándo.

## Scope

1. `scripts/context-condenser.sh` — wrapper bash que detecta context overflow (>120 events en session log) y llama a `scripts/context-condenser.py`. Acepta flags `--dry-run` y `--session-log <path>`.
2. `scripts/context-condenser.py` — lee `output/session-action-log.jsonl`, aplica rolling window (head=4, tail=60), llama a Haiku via API para comprimir el segmento medio, genera `Condensation` entry en la memoria episódica.
3. Hook PostTurn en `.claude/settings.json` que invoca `context-condenser.sh` tras cada turno completado.
4. Config: `SAVIA_CONDENSER_MAX_SIZE=120`, `SAVIA_CONDENSER_KEEP_HEAD=4`, `SAVIA_CONDENSER_KEEP_TAIL=60` — todas sobreescribibles via env.
5. `docs/rules/domain/context-condenser-protocol.md` — protocolo: qué se comprime, formato de Condensation entry, política de retención.

## Acceptance Criteria

- AC1: `context-condenser.sh` detecta session log >120 líneas y genera Condensation entry en `output/condensations-{fecha}.jsonl`.
- AC2: Head (4 primeros eventos) y tail (60 últimos) preservados íntegros en la Condensation entry, sin modificación.
- AC3: Hook PostTurn registrado en `.claude/settings.json` con evento correcto y path al script.
- AC4: `SAVIA_CONDENSER_MAX_SIZE` configurable vía env; default 120.
- AC5: Condensation entry escrita en `output/condensations-{fecha}.jsonl` con campos: `timestamp`, `session_id`, `events_total`, `events_condensed`, `summary`.
- AC6: `--dry-run` muestra qué segmento se comprimiría (índices head/middle/tail) sin ejecutar la llamada LLM ni escribir ficheros.
- AC7: Si session log < `max_size`, script sale con exit 0 sin hacer nada ni escribir nada.

## Slices

1. **Slice 1 (2h)** — `context-condenser.sh` + detección de overflow + `--dry-run` + BATS básicos (exit 0 si < max, detección si >).
2. **Slice 2 (3h)** — `context-condenser.py` + rolling window + llamada Haiku + Condensation entry en jsonl + tests de integración.
3. **Slice 3 (1h)** — Hook PostTurn en `settings.json` + validación en BATS que el hook está registrado.
4. **Slice 4 (1h)** — `context-condenser-protocol.md` + test BATS E2E con session log sintético >120 líneas.

## Out of scope

- Compresión multi-nivel (comprimir condensaciones anteriores).
- UI para visualizar condensaciones.
- Soporte para otros formatos de session log distintos de `.jsonl`.
- Integración con sistemas de memoria L2/L3 (eso es un SPEC posterior).

## Riesgo principal

La llamada a Haiku en el hook PostTurn añade latencia perceptible (~1-2s) en cada turno si el log está cerca del umbral. Mitigación: ejecutar `context-condenser.sh` en background (`&`) y loguear errores sin bloquear el turno.
