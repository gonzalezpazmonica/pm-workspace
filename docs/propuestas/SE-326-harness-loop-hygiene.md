---
id: SE-326
title: "SE-326 — Loop-hygiene, spill y token-meter desde deepseek-harness"
status: IMPLEMENTED
priority: media
---

# SE-326 — Loop-hygiene, spill y token-meter desde deepseek-harness

**Status:** IMPLEMENTED
**Fecha:** 2026-08-14
**Area:** Hooks / Autonomía / Contexto / Seguridad
**Branch sugerida:** `agent/se326-harness-improvements`
**Estimacion total:** ~32h (5 slices)
**Inspiracion:** deepseek-ai/deepseek-harness (`dsh`) — https://github.com/deepseek-ai/deepseek-harness

---

## Contexto y evidencia (2026-08-14)

deepseek-harness es un agent harness plugin-based (Cordis) en developer preview.
De sus `packages/` y `docs/` extraigo 5 patrones con **gap real en Savia/opencode**
(fuentes citadas abajo):

| Patrón dsh | Dónde vive en dsh | Gap actual en Savia |
|---|---|---|
| **Repeat-tool guard** | `packages/guard/repeat-tool-reminder` | Savia tiene `auto-loop-gate.sh` (clasifica requests en loop/single-shot) y `loop-budget-check.sh` (presupuesto de tokens/rondas), pero **ningún detector de llamadas de tool repetidas con args idénticos en cadena** |
| **Spill storage** | `packages/spill/spill-local` + `spill-policy` | `bash-output-compress.sh` solo trunca output inline; no persiste el contenido completo a fichero privado con locator + hint |
| **Token meter** | `packages/llm/token-meter` | `context-rot-strategy` (skill) estima porcentajes a mano; no hay medición determinista de la superficie de la sesión |
| **Same-session goals** | `packages/goal/goal` | `loop-budget-check.sh` limita rondas, pero no hay objetivo durable por sesión con fases, revisiones CAS ni bloqueo con razón |
| **Env scrubbing** | `docs/defensive-patterns.md` ("Never hand untrusted output the ambient environment") | `block-credential-leak.sh` detecta PATs en comandos, pero no sanitiza el entorno heredado antes de spawn |

**Lo que Savia NO necesita** (ya cubierto o no aplica):
- Subagent seam con providers múltiples → ya hay 83 agentes vía `Task` tool.
- Session log event-sourced → `agent-trace-log.sh` + memoria L0-L3 cubren trazabilidad.
- Schedule/session-local reminders → `automation-scheduler` (SE-304) ya lo cubre.
- Hooks bridges Claude Code/Codex → Savia ya es multi-frontend (`.claude/hooks` + `.opencode/hooks`).
- Message feedback con CAS → telemetría anti-adulation (SPEC-192) + doc-quality-feedback cubren el eje de feedback.

---

## Objetivo

Transferir los 5 patrones de higiene de loop y defensa de contexto a Savia/opencode,
manteniendo el principio **"la IA propone, el humano dispone"** (autonomous-safety):

1. **Repeat-tool guard**: detectar llamadas repetidas idénticas (tool + args
   canonicalizados) y emitir recordatorio escalonado — nunca bloquear.
2. **Spill storage**: persistir outputs grandes a fichero privado (0700, `'wx'`
   0o600, symlink-safe) con locator + retrieval hint en vez de truncar.
3. **Token-meter determinista**: medir la superficie de una sesión con heurística
   y alimentar context-rot-strategy + telemetría.
4. **Goal service por sesión**: objetivo durable con fases, revisiones CAS y round
   cap, integrado con loop-budget.
5. **Env scrubbing defensivo**: sanitizar `*KEY*`/`*SECRET*`/`*TOKEN*`/`*PASSWORD*`/
   `*PAT*` antes de spawn, sin romper flujos legítimos.

---

## Out of scope

- NO portar Cordis ni el event-sourcing de `dsh`.
- NO sustituir `auto-loop-gate.sh` ni `loop-budget-check.sh` — los complementa.
- NO crear un plugin runtime para opencode; todo son hooks `*.sh` + scripts bash/python.
- NO persistir spill fuera del workspace (`output/spill/` es el único root).
- NO tocar la detección de secrets existente (`block-credential-leak.sh`).

---

## Diseno

### S1 — Repeat-tool guard (loop-hygiene)

`scripts/repeat-tool-guard.py` (stdlib python, sin deps) + hook
`.opencode/hooks/repeat-tool-guard.sh` (PostToolUse, async, exit 0 siempre):

- **Chain key** = `(tool_name, canonicalized_args)` — canonicalización: deep
  key-sort + `json.dumps`. Args idénticos en orden distinto cuentan como iguales.
- **Per-sesión**: estado en `output/loop-guard/{session-id}.json` (WeakMap→dir
  por sesión). Un `user/message` nuevo (detectado vía hook SessionStart/Stop o
  marca de turno) resetea la cadena de esa sesión.
- **Thresholds escalonados** `[3, 5, 8]` (default; configurables):
  - 1er threshold: nudge genérico en stderr ("Repites la misma llamada... re-lee
    el último resultado o cambia de enfoque").
  - thresholds posteriores: detalle con tool, run length y preview de args cap
    a 500 chars (`… (+N more chars)`).
- **Exclusiones por defecto** (`exclude`): `todo_write`, `todowrite` (bookkeeping
  no "lava" la cadena — no incrementa ni resetea).
- **NUNCA bloquea**: el guard solo escribe recordatorio; la decisión queda en el
  modelo (igual que `repeat-tool-reminder`).
- **In-memory por defecto**; `--persist` opcional para diagnóstico.
- Emite telemetría `savia.loop-guard` (schema savia.event/1.0, SE-313) con
  `{tool, run_length, threshold}`.

### S2 — Spill storage seguro

`scripts/spill-save.sh` (wrapper sobre python stdlib) + política en
`bash-output-compress.sh`:

- **Umbral**: output Bash > 200 líneas **o** > 16 KB (configurable vía env
  `SPILL_MAX_INLINE_LINES` / `SPILL_MAX_INLINE_BYTES`).
- **Destino**: `output/spill/{session-id}/{random}-{safeName}` bajo root privado
  `output/spill/` con permisos `0700` (dir) y `0o600` + open `'wx'` (exclusivo)
  para que un symlink plantado no pueda redirigir la escritura.
- **safeName** derivado del nombre sugerido, sanitizado a un único segmento de
  path; el random evita colisiones y adivinanza.
- **Resultado**: reemplaza el output inline por preview head/tail (~40 líneas
  total) + locator + retrieval hint:
  ```
  [spill] output completo en output/spill/<session>/<archivo> (N bytes)
  [spill] usa Read/Grep sobre esa ruta para el contenido íntegro
  ```
- **Best-effort**: si `spill-save` falla (permisos, ENOSPC), mantiene el output
  inline original — nunca convierte una llamada exitosa en error.
- Verifica `lstatSync().isSymbolicLink()` antes de unlink en limpieza (patrón
  "unlink link-shaped paths" de dsh).

### S3 — Token-meter determinista

`scripts/token-meter.py` (stdlib) + comando `/token-meter`:

- **Heurística de pricing** por mensaje: `role framing` + `chars/4` (aprox.
  tokens), con ajuste por tipo de contenido (tool result ≥ 3x que user text).
- **Snapshot inmutable** `output/token-meter/{session}.json`:
  `{log_revision, total_tokens, surface_tokens, nodes:[{seq, tokens}]}` —
  `log_revision` = nº de eventos durábiles consumidos (derivado del trace log de
  la sesión si existe, si no `0`).
- **Baseline provider**: si existe `usage` del último call (de telemetría SE-313),
  lo reutiliza como ancla; si no, estimación heurística completa. `surface_delta`
  preserva crecimiento/shrinkage respecto al ancla.
- **Consumo**: alimenta `context-rot-strategy` (nivel real en vez de % manual),
  `loop-budget-check.sh` y telemetría `savia.token-meter`.
- Medición O(surface) — se clonan los nodos posicionales, sin mutar nada.

### S4 — Same-session goal service

`scripts/goal-service.sh` (subcomandos `create/edit/pause/resume/complete/block/clear/get`)
+ estado durable en `output/goals/{session-id}.json`:

- **Fases**: `active | paused | blocked | complete`. `blocked` exige
  `blocked_reason: {code, message}` (code kebab-case estable para routing).
- **CAS**: cada mutación durable incrementa `revision`; el caller pasa el `ref`
  esperado (`id + revision`) o falla con conflicto.
- **Round cap**: `max_goal_rounds` (default 10, configurable). Cada turno
  admitido a favor del goal incrementa `rounds_started`; al alcanzar el cap el
  goal pasa a `blocked` con `code: 'round-cap-reached'`.
- **Atribución**: las entradas `user/message` admitidas para el goal se marcan
  `{kind:'goal', goal_id, revision, round}`.
- **Integración**: `loop-budget-check.sh --skill <s> --goal <id>` reutiliza el cap
  de rondas del goal en vez del default de la skill.
- Tombstone en `clear` (retiene histórico; el id no se reutiliza).

### S5 — Env scrubbing defensivo

`scripts/env-scrub.sh` + integración en el hook global `agent-git-discipline.sh`
(que ya envuelve Bash global):

- **Regla**: antes de ejecutar un comando que spawna un subproceso (Bash tool),
  se construye un entorno con las variables que matchean
  `*KEY*|*SECRET*|*TOKEN*|*PASSWORD*|*PAT*` **drenadas** (siempre que exista
  fuente canónica alternativa y el flag `SAVIA_SCRUB_ENV=1` esté activo).
- **Por defecto OFF** (`SAVIA_SCRUB_ENV` unset → no toca nada): las sesiones
  interactivas con la operadora no cambian de comportamiento.
- **Modo ON**: `env -i` + allowlist explícita (`PATH`, `HOME`, `SHELL`, `LANG`,
  `CLAUDE_PROJECT_DIR`, vars del workspace conocidas) + las credenciales se
  pasan SOLO vía ficheros `$(cat $PAT_FILE)` (Rule #1), nunca por env.
- **Validación**: el hook verifica que el comando no invente una var secret en el
  entorno si `SAVIA_SCRUB_ENV=1`; warning en stderr, nunca bloqueo.
- Telemetría `savia.env-scrub` con `{mode, dropped_vars}` cuando scrub activo.

---

## Criterios de aceptacion

### AC-S1: Repeat-tool guard

- [ ] AC-S1.1: 3 llamadas `Read` idénticas seguidas → aparece el nudge genérico.
- [ ] AC-S1.2: 5 llamadas idénticas → aparece el recordatorio detallado con tool y run length.
- [ ] AC-S1.3: `grep X` + `todo_write` + `grep X` cuenta como 2 consecutivas (exclude no lava la cadena).
- [ ] AC-S1.4: args en distinto orden cuentan como idénticas (canonicalización).
- [ ] AC-S1.5: una llamada distinta resetea la cadena.
- [ ] AC-S1.6: el guard nunca bloquea (exit 0 siempre, incluso en threshold).
- [ ] AC-S1.7: telemetría `savia.loop-guard` registrada en telemetry-events.jsonl.

### AC-S2: Spill

- [ ] AC-S2.1: output > umbral → fichero en `output/spill/{session}/` con 0600 y dir 0700.
- [ ] AC-S2.2: output inline reemplazado por preview + locator + hint.
- [ ] AC-S2.3: fallo simulado de spill-save (permisos) → output inline intacto, sin error.
- [ ] AC-S2.4: nombre sugerido con `/` o `..` → sanitizado a un segmento.
- [ ] AC-S2.5: symlink plantado en el path destino → escritura falla seguro (open 'wx').
- [ ] AC-S2.6: limpieza de un symlink → lstat/unlink, no rm recursivo.

### AC-S3: Token-meter

- [ ] AC-S3.1: `scripts/token-meter.py --session <id>` emite snapshot JSON con total/surface/nodes.
- [ ] AC-S3.2: `surface_tokens` == suma de tokens de los nodos.
- [ ] AC-S3.3: medición no muta ningún fichero de sesión (inmutable).
- [ ] AC-S3.4: comando `/token-meter` invocable.
- [ ] AC-S3.5: telemetría `savia.token-meter` registrada.

### AC-S4: Goal service

- [ ] AC-S4.1: `create` → fase `active`, revision 1, round 0.
- [ ] AC-S4.2: mutación con `ref` desactualizado → error `version-conflict`.
- [ ] AC-S4.3: al llegar a `max_goal_rounds` → fase `blocked`, code `round-cap-reached`.
- [ ] AC-S4.4: `block` exige `blocked_reason.code` y `.message` no vacíos.
- [ ] AC-S4.5: `clear` retiene tombstone; el id no se reutiliza.
- [ ] AC-S4.6: `loop-budget-check.sh --goal <id>` usa el cap del goal.
- [ ] AC-S4.7: estado durable en `output/goals/{session}.json` (no en el repo).

### AC-S5: Env scrub

- [ ] AC-S5.1: con `SAVIA_SCRUB_ENV=1`, un comando Bash recibe env sin `*KEY*/*SECRET*/*TOKEN*/*PASSWORD*/*PAT*`.
- [ ] AC-S5.2: con `SAVIA_SCRUB_ENV` unset, comportamiento idéntico al actual.
- [ ] AC-S5.3: `$(cat $PAT_FILE)` sigue funcionando con scrub activo.
- [ ] AC-S5.4: telemetría `savia.env-scrub` registrada solo cuando scrub activo.
- [ ] AC-S5.5: `.claude/hooks/agent-git-discipline.sh` integra la validación `env-scrub check` (warning, nunca bloqueo).

### AC-S6: Integración y registro

- [ ] AC-S6.1: hook `repeat-tool-guard.sh` registrado en `.claude/settings.json` (PostToolUse `.*`).
- [ ] AC-S6.2: `docs/hooks-coverage-matrix.md` documenta el hook repeat-tool-guard.
- [ ] AC-S6.3: comando `/token-meter` registrado en el catálogo SCM (`.scm/` regenerado).
- [ ] AC-S6.4: `docs/propuestas/INDEX.md` regenerado con SE-326 IMPLEMENTED.

---

## Ref

- deepseek-ai/deepseek-harness (github.com/deepseek-ai/deepseek-harness):
  - `packages/guard/repeat-tool-reminder/README.md` — thresholds, chain key, exclude.
  - `packages/spill/spill-local` + `packages/spill/spill-policy` — 0700/'wx'/0o600,
    symlink-safe, best-effort.
  - `packages/llm/token-meter` — snapshot inmutable, baseline provider, O(surface).
  - `packages/goal/goal` — fases, revisiones CAS, round cap, blocked reason.
  - `docs/defensive-patterns.md` — env scrubbing, unlink link-shaped paths.
- Savia: `scripts/auto-loop-gate.sh`, `scripts/loop-budget-check.sh`,
  `.opencode/hooks/bash-output-compress.sh`, `.opencode/hooks/block-credential-leak.sh`,
  `.opencode/skills/context-rot-strategy/SKILL.md`, `docs/rules/domain/autonomous-safety.md`,
  `docs/rules/domain/loop-budget-schema.md`.

## Implementación (2026-08-14)

- `scripts/repeat-tool-guard.py` + `.opencode/hooks/repeat-tool-guard.sh`
  (opt-in `SAVIA_LOOP_GUARD=1`, thresholds [3,5,8], exclude todo_write/todowrite,
  canonicalización key-sort, persistencia por (sesión, turno), NUNCA bloquea,
  telemetría `savia.loop-guard`).
- `scripts/token-meter.py` + comando `/token-meter` (snapshot inmutable, heurística
  por rol, baseline provider, telemetría `savia.token-meter`).
- `scripts/spill-save.sh` + integración en `bash-output-compress.sh` (dir 0700,
  open 'wx' 0o600, nombre sanitizado, preview+locator+hint, best-effort).
- `scripts/env-scrub.sh` + validación en `agent-git-discipline.sh`
  (opt-in `SAVIA_SCRUB_ENV=1`, env -i + allowlist, warning nunca bloqueo).
- `scripts/goal-service.{sh,py}` + integración `loop-budget-check.sh --goal`
  (fases, CAS, round-cap, tombstone; estado en `output/goals/`).
- 32 tests BATS (5 ficheros). Registro del hook en `.claude/settings.json`
  (PostToolUse `.*`).

## Plan de implementación propuesto

| Slice | Prioridad | Depende de | Estimación |
|---|---|---|---|
| S1 repeat-tool-guard | alta | — | 8h |
| S3 token-meter | alta | — | 6h |
| S2 spill | media | S3 (umbral en bytes) | 6h |
| S5 env-scrub | media | — | 4h |
| S4 goal-service | baja | loop-budget | 8h |

Orden recomendado: S1 → S3 → S2 → S5 → S4. Cada slice con tests BATS
(`tests/test-repeat-tool-guard.bats`, `tests/test-token-meter.bats`,
`tests/test-spill.bats`, `tests/test-goal-service.bats`, `tests/test-env-scrub.bats`).
