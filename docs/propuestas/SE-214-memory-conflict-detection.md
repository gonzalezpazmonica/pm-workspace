---
spec_id: SE-214
title: Conflict detection for decision and instruction memory entries
status: IMPLEMENTED
priority: P2
effort: L
era: 202
origin: output/research/memanto-savia-20260607.md
inspiration: Memanto conflict detection — supersede/retain/annotate on contradictory memories
---

# SE-214 — Conflict detection in memory-store save

## Problema

Al guardar múltiples entradas de tipo `decision` o `instruction` a lo largo del tiempo, pueden acumularse contradicciones sin detección. Memanto resuelve esto con un check semántico en write-time que detecta solapamiento temático con diferente valor y ofrece tres acciones: supersede, retain, annotate.

## Solución

Al guardar una nueva entrada de tipo `decision` o `instruction`, hacer un check semántico contra entradas existentes del mismo tipo para detectar posibles contradicciones. Emite WARN (no bloquea).

## Scope

### 1. `scripts/memory-conflict-check.sh`

Dado un nuevo contenido y tipo, busca en el KG entidades del mismo tipo, compara con keyword overlap (no requiere LLM), emite WARN si hay solapamiento temático con diferente valor.

Uso:
```
bash scripts/memory-conflict-check.sh "contenido nuevo" decision
```

Output si hay conflicto:
```
[CONFLICT-WARN] Nueva entry 'X' puede contradecir 'Y' (2026-03-01). Revisar antes de guardar.
```

### 2. Integración en `scripts/memory-store.sh save`

Check opcional activado por variable de entorno:

- `SAVIA_CONFLICT_CHECK=true` — activa el check
- `SAVIA_CONFLICT_CHECK=false` — default hasta calibración

Flujo: si `SAVIA_CONFLICT_CHECK=true`, ejecutar el check antes de guardar. El WARN no bloquea — la entrada se guarda igual.

### 3. `output/memory-conflicts-{date}.jsonl`

Log de conflictos detectados para revisión humana. Campos por línea:

```
{"ts":"2026-06-07T10:00:00Z","new":"contenido nuevo","conflict":"contenido antiguo","date_conflict":"2026-03-01","type":"decision"}
```

### 4. Tres opciones documentadas (solo documentadas, no automatizadas)

| Acción | Descripción |
|---|---|
| supersede | Borrar la entrada antigua, guardar la nueva |
| retain | Mantener ambas (convivencia de versiones) |
| annotate | Añadir nota de relación entre ambas |

La elección es siempre humana. El script solo detecta y sugiere.

## Acceptance Criteria

- **AC1**: `memory-conflict-check.sh "contenido" decision` imprime WARN si hay entradas similares con diferente valor
- **AC2**: `SAVIA_CONFLICT_CHECK=false` (default) — no bloquea por defecto
- **AC3**: conflictos se loguean en JSONL para revisión posterior
- **AC4**: funciona solo con keyword matching (no requiere API LLM)
- **AC5**: no modifica entradas existentes automáticamente — solo sugiere

## OpenCode Implementation Plan

```yaml
classification: PURE_BASH
files_touched:
  - scripts/memory-conflict-check.sh
  - scripts/memory-store.sh
requires_restart: false
verification: SAVIA_CONFLICT_CHECK=true bash scripts/memory-store.sh save decision "test conflict"
```

## Referencias

- SE-211 — Typed memory schema (prerequisito: memory_type en KG)
- `scripts/memory-store.sh` — store de memoria persistente
- `scripts/knowledge-graph.py` — KG consultado por el conflict checker
- `docs/ROADMAP.md#era-202` — Era 202 Memory intelligence upgrade
