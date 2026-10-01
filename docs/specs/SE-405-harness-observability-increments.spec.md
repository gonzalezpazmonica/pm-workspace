---
status: APPROVED
approved_at: 2026-09-27
approval: "Operadora 2026-09-27: 'Redacta todas las specs que necesites y adelante con todas las propuestas en sprint nocturno'"
priority: P2
developer_type: agent-single
created: 2026-09-27
phase: A
risk: L1
related_specs: [SE-349, SE-343, SPEC-018]
origin: output/research/harness-mejoras-20260927.md (P5, P6, P7; gentle-ai, engram)
---

# SE-405 — Incrementos de observabilidad: coste por subagente, snapshots de configuración, timeline de memoria

Tres mejoras pequeñas e independientes. Cada una es un slice con su propio test.

## Slice 1 — Coste por subagente en el ledger de runs (P5)

**Problema.** `savia-runs.sh` (SE-349) registra estado, PR y CI de cada run
autónomo, pero no cuánto costó ni qué subagente lo consumió. `agent-cost` lee
trazas por proyecto, desconectadas del run.

**Diseño.**
- `savia-runs.sh cost <run_id> --agent A --model M --tokens-in N --tokens-out N [--usd X]`
  añade un hecho `cost` al ledger (append-only, como el resto de hechos).
- `show` y `status --json` agregan por run: tokens in/out, USD (si se conoce) y
  desglose por agente.
- Hook `SubagentStop` (Claude Code) → `savia-runs.sh capture-cost`: si hay
  `SAVIA_RUN_ID` en el entorno y el payload trae `transcript_path`, suma el `usage`
  de los mensajes del subagente y llama a `savia-runs.sh cost`. Sin `SAVIA_RUN_ID`, no hace nada.

**AC.**
- AC1: `cost` valida run existente, enteros ≥ 0 y agente no vacío; rechaza lo demás con exit 2.
- AC2: `show <run_id>` muestra total y desglose por agente; `status --json` incluye `cost`.
- AC3: `savia-runs.sh capture-cost` suma `usage.input_tokens`/`output_tokens` de un transcript JSONL de fixture.

## Slice 2 — Snapshots de configuración (P6)

**Problema.** `.claude/settings.json` (124 hooks registrados) y
`~/.savia/preferences.yaml` se editan a mano o por scripts sin copia previa. Un
error deja el arranque roto y sin forma rápida de volver.

**Diseño.**
- `scripts/config-snapshot.sh snapshot <file> | list [<file>] | restore <id> --confirm`.
- Destino `~/.savia/config-snapshots/<basename>/<UTC>-<sha8>` (local). Retención: 30 por fichero.
- Hook PreToolUse `Edit|Write` → snapshot automático si la ruta es
  `.claude/settings.json`, `.claude/settings.local.json`, `opencode.json` o
  `~/.savia/preferences.yaml`. Nunca bloquea.
- `restore` exige `--confirm` y hace snapshot del estado actual antes de restaurar.

**AC.**
- AC4: Editar un fichero vigilado crea un snapshot idéntico al contenido previo.
- AC5: `restore` sin `--confirm` → exit 2 sin cambios; con `--confirm` restaura y deja snapshot del estado sustituido.
- AC6: Se conservan como máximo 30 snapshots por fichero.

## Slice 3 — Timeline de memoria (P7)

**Problema.** `memory-store.sh search` devuelve entradas sueltas. Falta el paso
engram de "contexto alrededor": qué se guardó justo antes y después.

**Diseño.** `memory-store.sh timeline <topic_key|prefijo de hash> [--window N]` (los registros no tienen `id`) → las N
entradas anteriores y posteriores (por `ts`) del mismo `project` (o de todo el
store si no hay proyecto), marcando la entrada ancla.

**AC.**
- AC7: `timeline` con un `topic_key` o prefijo de hash existente devuelve ancla + hasta N antes y N después, en orden temporal.
- AC8: ancla inexistente → exit 1 con mensaje; `--window` no numérico → exit 2.

## Común

- AC9: Tests BATS aislados (`HOME`, stores y ledgers temporales); auditor ≥ 80 por fichero.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| `savia-runs.sh cost` | bash | idéntico |
| Captura de coste | hook `SubagentStop` → `savia-runs.sh capture-cost` | sin evento equivalente: `cost` manual (deferred) |
| Snapshot de config | hook PreToolUse `Edit\|Write` → `config-snapshot-hook.sh` | `tool.execute.before` en `savia-foundation.ts` invoca el mismo script |
| `memory-store.sh timeline` | bash | idéntico |

### Verification protocol

- [ ] Slices 2 y 3 funcionan igual en ambos runtimes
- [ ] Slice 1: captura automática solo en Claude Code; comando manual en ambos
- [ ] Hooks registrados en settings.json y en el plugin

### Portability classification

- [x] **SINGLE_BINDING_DEFERRED**: la captura automática de coste depende del evento `SubagentStop` de Claude Code; en OpenCode el registro es manual hasta que exista evento equivalente (se revisará en SE-392). Slices 2 y 3 son DUAL/PURE_BASH.

## Ficheros afectados fuera de los slices

- Recuentos de hooks en `README*.md` y `CLAUDE.md` (exigidos por `release-invariants.sh`).
- `docs/hooks-coverage-matrix.md` regenerada (SE-253).
- Tests TS del plugin: `.opencode/plugins/__tests__/config-snapshot.test.ts`.
- Entropía neta 0 (SE-380): se retira `scripts/corporate/engagement-evidence-package.sh` (SE-271 PROPOSED, sin llamadores) y la captura de coste vive en `savia-runs.sh capture-cost`.

## Resultados (verificación 2026-10-01)

| AC | Evidencia | Estado |
|---|---|---|
| AC1–AC3 | `tests/test-se405-runs-cost.bats` (10): validación de `cost`, `show` con desglose, `status --json` con `cost`, `capture-cost` desde transcript y el hook SubagentStop de extremo a extremo | OK |
| AC4–AC6 | `tests/test-se405-config-snapshot.bats` (10): snapshot idéntico, `restore` sin `--confirm` ⇒ exit 2, con `--confirm` restaura y guarda el estado sustituido, retención de 30 | OK |
| AC7–AC8 | `tests/test-se405-memory-timeline.bats` (9): ancla por `topic_key` o prefijo de hash, ventana en orden temporal, ancla inexistente ⇒ exit 1, `--window` no numérico ⇒ exit 2 | OK |
| AC9 | 29/29 BATS aislados; auditor 84, 84 y 89 | OK |

