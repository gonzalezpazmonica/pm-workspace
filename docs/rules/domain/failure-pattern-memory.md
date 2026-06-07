---
context_tier: L2
token_budget: 600
spec: SPEC-188
---

# Failure Pattern Memory — SPEC-188 Fase 1

> Store SQLite en `.claude/external-memory/failure-patterns/patterns.db`.
> Agrega frecuencia de fallos por agente. Complementa `memory-store.sh` (decisiones puntuales).
> Feature flag: `SAVIA_FAILURE_PATTERN_MEMORY_ENABLED` (default `0`).

## Que es

Memoria de patrones de fallo con conteo de ocurrencias. Un patron = (agent, error_signature, file_glob).
Diferencia con `memory-store.sh`: ese guarda eventos unicos; failure-patterns agrega N eventos del mismo patron.

## Schema

```sql
CREATE TABLE failure_patterns (
  pattern_id      TEXT PRIMARY KEY,   -- 8 chars sha256(agent+error_signature+file_glob)
  agent           TEXT NOT NULL,
  error_signature TEXT NOT NULL,      -- 2 primeras lineas del error, normalizado
  file_glob       TEXT,               -- ej. tests/**/*.bats
  occurrences     INTEGER DEFAULT 1,
  first_seen      TEXT NOT NULL,      -- ISO-8601
  last_seen       TEXT NOT NULL,
  human_lesson    TEXT,               -- leccion post-mortem (humano)
  status          TEXT DEFAULT 'open', -- open | acknowledged | resolved
  verified_source TEXT DEFAULT 'tool:post-tool-failure-log'
);
```

## Cuando usar

| Trigger | Accion |
|---|---|
| Post-tool-failure-log detecta fallo repetido | `add --agent <name> --error <signature>` |
| `responsibility-judge` evalua shortcut | Consulta `list --agent <name>` para contexto |
| `recommendation-tribunal` inline | Si patron abierto coincide, emite banner WARN |
| Revision manual / post-mortem | `show <pattern_id>` + `resolve <pattern_id> --lesson <texto>` |

## Comandos CLI

```bash
bash scripts/failure-pattern-memory.sh init
bash scripts/failure-pattern-memory.sh add --agent court-orchestrator --error "threshold below 80" [--file-glob tests/**/*.bats] [--lesson texto]
bash scripts/failure-pattern-memory.sh list [--agent <name>] [--status open|acknowledged|resolved]
bash scripts/failure-pattern-memory.sh show <pattern_id>
bash scripts/failure-pattern-memory.sh resolve <pattern_id> [--lesson <texto>]
bash scripts/failure-pattern-memory.sh stats
```

## Feature flag

`SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1` activa escritura y lectura.
`=0` (default): todos los subcomandos excepto `stats` e `init` son no-op con mensaje informativo.
Sin codigo de estado: el sistema funciona sin P1 cuando el flag esta apagado.

## Bridge con feedback permanente

Cuando `occurrences >= 10`, el script emite aviso de promocion a regla permanente.
Path canonico: `.claude/rules/domain/feedback/feedback_root_cause_always.md`.

## Bridge SE-072 verified-memory-axiom

Cada insert lleva `verified_source = 'tool:post-tool-failure-log'` por defecto.
Requisito del axioma SE-072: toda memoria persistida tiene fuente verificada no nula.

## Ubicacion del store

`.claude/external-memory/failure-patterns/patterns.db` gitignored (external-memory/).
El directorio se crea automaticamente en `init` y en el primer `add`.
