---
context_tier: L2
token_budget: 600
spec_ref: SE-200
---

# Context Condenser Protocol

## Qué es

El context condenser (SE-200) aplica una ventana deslizante de compresión sobre el `session-action-log.jsonl` cuando supera el umbral de `max_size` eventos. Evita context overflow silencioso que degrada la calidad de respuesta en sesiones largas.

Patrón inspirado en el `LLMSummarizingCondenser` de OpenHands: preserva el intent original (head) y el estado reciente (tail); comprime el segmento medio en una `Condensation` entry.

## Cuándo se activa

- Automáticamente via hook PostTurn cuando `wc -l session-action-log.jsonl > SAVIA_CONDENSER_MAX_SIZE` (default 120).
- Manualmente: `bash scripts/context-condenser.sh`.
- Con `--dry-run`: muestra qué se comprimiría sin escribir nada.
- Con `--stats`: imprime métricas sin condensar.

## Variables de configuración

| Variable | Default | Descripción |
|---|---|---|
| `SAVIA_CONDENSER_MAX_SIZE` | `120` | Umbral de eventos antes de comprimir |
| `SAVIA_CONDENSER_KEEP_HEAD` | `4` | Primeros N eventos a preservar íntegros |
| `SAVIA_CONDENSER_KEEP_TAIL` | `60` | Últimos N eventos a preservar íntegros |

## Formato de la Condensation entry

Línea JSONL escrita en `output/condensations-YYYYMMDD.jsonl`:

```json
{
  "type": "condensation",
  "timestamp": "2026-06-07T14:00:00+00:00",
  "session_id": "session-action-log",
  "events_total": 58,
  "events_condensed": 58,
  "summary": "58 events compressed: 30x observation, 20x action, 8x unknown",
  "spec": "SE-200"
}
```

## Política de retención

- El `session-action-log.jsonl` se reescribe con: `head[0..KEEP_HEAD]` + entrada de condensación + `tail[-KEEP_TAIL..]`.
- La entrada de condensación se añade también a `output/condensations-YYYYMMDD.jsonl` (append).
- El fichero de condensaciones no se trunca — acumula una entrada por ejecución del condenser.

## Flujo de scripts

```
context-condenser.sh     → detecta overflow, valida flags
    ↓
context-condenser.py     → rolling window + Condensation entry
    ↓
output/condensations-YYYYMMDD.jsonl  (append)
output/session-action-log.jsonl      (rewrite condensed)
```
