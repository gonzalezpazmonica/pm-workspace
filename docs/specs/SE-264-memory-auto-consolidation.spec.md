# Spec: SE-264 — Memory Auto-Consolidation (dedup + strip + stale flag)

**Status:** IMPLEMENTED (2026-08-27, PR Batch 1 L14)
**Fecha:** 2026-08-27
**Area:** Memory / Autonomía
**Estimacion:** S 3h (agente)
**Developer Type:** agent-single
**Inspirado por:** exxperts (memory hygiene) + lección Savia: MEMORY.md con entradas de tests/bench repetidas que inflan el índice.
**CRIT-001:** todo local (`~/.savia-memory/`, `output/`); sin datos a proveedor cloud.

---

## 1. Contexto y objetivo

`memory-store.sh` escribe `output/.memory-store.jsonl` y sincroniza el índice
`~/.savia-memory/auto/MEMORY.md`. Problemas observados:

1. **Duplicación**: entradas con el mismo `topic_key` (p.ej. sesiones de test
   repetidas, `ep-*`, `episode: many`) se duplican o compiten por el índice.
2. **Ruido de tests/bench**: corridas de tests, evals y fixtures producen
   entradas de memoria sin valor (`episode: many`, `test rebuild`, etc.) que
   inflan el índice y degradan el recall.
3. **Stale sin marcar**: entradas viejas que no se leen ni referencian nunca se
   señalan, por lo que el recall trae basura y el soft cap (200) recorta
   entradas buenas antes que malas.

**Objetivo**: un comando `memory-store.sh consolidate` (local, determinista,
report-first) que:
- **Deduplica** entradas del JSONL por `topic_key` (conserva la más reciente y
  con más contenido).
- **Strippea** entradas de tests/bench (heurística por tipo/título/origen).
- **Marca stale** entradas sin lecturas ni referencias > N días (en vez de
  borrarlas: se archivan a `MEMORY-ARCHIVE.md` y se marcan `stale: true`).
- Emite un **informe** (`output/memory-consolidation-{fecha}.md`) con
  `{scanned, deduped, stripped, stale, kept}` y `--dry-run` para prever.

La tarea programada `memory-consolidation` del automation-scheduler lo invoca
semanalmente (ya existe en `savia-automations.sh init-defaults`).

## 2. Contrato técnico

### 2.1 `memory-store.sh consolidate`

```
memory-store.sh consolidate [--dry-run] [--stale-days N] [--force]
```

- Lee `output/.memory-store.jsonl` línea a línea.
- **Dedupe**: índice por `topic_key`; si hay duplicados, conserva el más
  reciente (o el de mayor `content`); el resto se registra como `deduped`.
- **Strip tests/bench**: entradas cuyo `type` ∈ {episode, bug, pattern} y cuyo
  `title`/`topic` matchee heurística (regex) de tests/bench/evals
  (`test`, `bench`, `eval`, `fixture`, `repro`, `ep-`, `rebuild`, `assert`,
  `inject-test`). Se registran como `stripped` y se borran del JSONL
  (movidas a `output/memory-stripped-{fecha}.jsonl` — reversible).
- **Stale**: entradas sin `read_at`/`refs` y con `ts` más antiguo que
  `--stale-days` (default 90): se marcan `stale: true` en el JSONL y se
  archivan a `MEMORY-ARCHIVE.md` (no se borran).
- **Informe**: `output/memory-consolidation-{fecha}.md` con resumen.
- `--dry-run`: solo reporta, no modifica nada (read-only).
- Después, re-sincroniza el índice `MEMORY.md` (`_update_memory_index`).

### 2.2 Seguridad

- NUNCA borra entradas de tipo `decision`/`architecture`/`lesson` con origen
  humano (`human_authored`) — esas solo se marcan stale, nunca se strip.
- `--force` requiere doble confirmación (igual que skills autónomas).
- Todo reversible: los ficheros movidos quedan en `output/` (gitignored).

## 3. Requisitos funcionales

- REQ-01 `consolidate` existe y es determinista (misma entrada → mismo output).
- REQ-02 Dedupe por `topic_key` conservando la mejor entrada.
- REQ-03 Strip de entradas test/bench por heurística (regex) sin tocar las
  humanas.
- REQ-04 Stale: marca `stale: true` + archiva a MEMORY-ARCHIVE.md.
- REQ-05 `--dry-run` no modifica ficheros (read-only).
- REQ-06 Informe con `{scanned, deduped, stripped, stale, kept}`.
- REQ-07 Índice `MEMORY.md` re-sincronizado tras consolidar.
- REQ-08 Telemetría local `output/memory-consolidation-{fecha}.md`.

## 4. Criterios de aceptación

- AC-01 `memory-store.sh consolidate --dry-run` emite JSON/MD sin modificar nada.
- AC-02 Con un JSONL de prueba (2 duplicados + 2 test-entries + 1 stale):
  deduped=1, stripped=2, stale=1, kept=N, y el JSONL final no contiene los
  borrados.
- AC-03 Entradas `decision`/`architecture`/`human_authored` nunca se strip
  (test dedicado).
- AC-04 Índice MEMORY.md consistente tras consolidar (grep del marker).
- AC-05 `tests/test-memory-consolidate.bats` ≥ 6 tests verdes.
- AC-06 CRIT-001: sin llamadas de red en el código nuevo (grep).

## 5. Ficheros

| Fichero | Acción |
|---|---|
| `scripts/memory-store.sh` | MODIFY: comando `consolidate` |
| `scripts/memory-consolidate.py` | CREAR (lógica dedup/strip/stale) |
| `tests/test-memory-consolidate.bats` | CREAR (≥6 tests) |
| `docs/rules/domain/memory-consolidation.md` | CREAR (política) |

## 6. Test scenarios

1. Dry-run sobre JSONL sintético: report correcto, ficheros intactos.
2. Dedupe: 2 entradas mismo `topic_key` → 1 conservada (la más rica).
3. Strip: `episode: many`/`test rebuild`/`inject-test` → movidas a stripped.
4. Stale: entrada 120 días sin lecturas → `stale: true` + archivada.
5. Humana protegida: `decision` humana con título que contenga "test" → NO strip.
6. CRIT-001 grep: sin `http`/`requests`/`urllib`/`openai`/`anthropic`.

## 7. Riesgos / limitaciones

- La heurística strip puede tener falsos positivos → queda en `output/`
  (reversible) y `--dry-run` permite prever antes de aplicar.
- El stale por antigüedad ignora "memoria que se consulta raramente pero es
  valiosa" → se archiva (no borra) y puede volver con `restore`.
- Deps: solo stdlib + el python ya usado por memory-store.

## 8. Referencias

- `scripts/memory-store.sh` · `~/.savia-memory/auto/MEMORY.md`
- Skill: `savia-memory` · tarea `memory-consolidation` (automation-scheduler)
- Lección: inflación del índice (soft cap 200) con entradas de tests repetidas
