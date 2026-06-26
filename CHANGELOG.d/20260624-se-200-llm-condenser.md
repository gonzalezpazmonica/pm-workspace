# SE-200 — LLM Condenser: rolling window context compression

Date: 2026-06-24
Spec: docs/propuestas/SE-200-llm-condenser.md
Status: APPROVED → IMPLEMENTED

## Ficheros

- `scripts/context-condenser.sh` — wrapper bash con --dry-run, --stats, --session-log
- `scripts/context-condenser.py` — rolling window: head=4 + tail=60, condensation entry JSONL
- `docs/rules/domain/context-condenser-protocol.md` — protocolo de retención y formato
- `.claude/settings.json` — PostTurn hook (async, default OFF via SAVIA_CONDENSER_ENABLED)
- `tests/scripts/test_se200_context_condenser.py` — 7 tests

## ACs cubiertos

- AC1: exit 0 si log <= max_size; no escribe nada
- AC2: head (4) y tail (60) preservados íntegros
- AC3: hook PostTurn registrado en .claude/settings.json
- AC4: SAVIA_CONDENSER_MAX_SIZE configurable vía env
- AC5: condensation entry escrita con campos requeridos (timestamp, session_id, events_total, events_condensed, summary)
- AC6: --dry-run muestra segmento sin escribir ni llamar LLM
- AC7: log < max_size → exit 0 sin acción

## Notas

Hook PostTurn es async y default OFF (guard SAVIA_CONDENSER_ENABLED).
Llama context-condenser.py para la lógica de condensación real.
