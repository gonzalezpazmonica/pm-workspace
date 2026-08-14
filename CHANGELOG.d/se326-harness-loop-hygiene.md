---
version_bump: minor
section: Added
---

### Added

- SE-326 Loop-hygiene, spill y token-meter — 5 patrones transferidos de
  deepseek-ai/deepseek-harness (https://github.com/deepseek-ai/deepseek-harness):
  - **S1 Repeat-tool guard** (`scripts/repeat-tool-guard.py` +
    `.opencode/hooks/repeat-tool-guard.sh`, opt-in `SAVIA_LOOP_GUARD=1`):
    detecta llamadas de tool repetidas idénticas (tool + args canonicalizados,
    key-sort) por (sesión, turno), thresholds escalonados [3,5,8], recordatorio
    a stderr con preview de args cap 500 chars. Excluye bookkeeping
    (todo_write/todowrite, no lava la cadena). NUNCA bloquea (exit 0). Emite
    telemetría `savia.loop-guard`. Inspirado en `guard/repeat-tool-reminder`.
  - **S3 Token-meter** (`scripts/token-meter.py` + comando `/token-meter`):
    snapshot inmutable de presión de contexto `{log_revision, baseline,
    surface_delta, total, surface, nodes}` con heurística por rol (tool_result
    x3), baseline provider reutilizable, medición O(surface) sin mutar nada.
    Emite telemetría `savia.token-meter`. Inspirado en `llm/token-meter`.
  - **S2 Spill storage** (`scripts/spill-save.sh`, integrado en
    `bash-output-compress.sh`): outputs >200 líneas o >16KB persisten a
    `output/spill/{session}/{random}-{safeName}` con dir 0700, open 'wx' 0o600
    (symlink-safe), nombre sanitizado a un segmento, preview head/tail + locator
    + hint. Best-effort (fallo → output inline intacto). Inspirado en
    `spill/spill-local` + `spill-policy`.
  - **S5 Env scrub** (`scripts/env-scrub.sh`, validación integrada en
    `agent-git-discipline.sh`): opt-in `SAVIA_SCRUB_ENV=1`; `run` construye env
    mínimo (env -i + allowlist) que drena *KEY*/*SECRET*/*TOKEN*/*PASSWORD*/*PAT*;
    `check` emite warning si un comando inyecta secrets por env. Inspirado en
    `docs/defensive-patterns.md`.
  - **S4 Goal service** (`scripts/goal-service.{sh,py}`, integrado en
    `loop-budget-check.sh --goal <session>`): objetivo durable por sesión en
    `output/goals/{session}.json` con fases active/paused/blocked/complete,
    revisiones CAS, `max_goal_rounds` (blocked `round-cap-reached`), tombstone
    en clear. Inspirado en `goal/goal`.
  - 32 tests BATS: `tests/test-repeat-tool-guard.bats`,
    `tests/test-token-meter.bats`, `tests/test-spill.bats`,
    `tests/test-goal-service.bats`, `tests/test-env-scrub.bats`.

### Notes

- Todos los guards son best-effort/warn o opt-in por env: **nada bloquea el
  flujo por defecto** (principio "la IA propone, el humano dispone").
- Estado durable siempre fuera del repo (`output/spill/`, `output/goals/`,
  `output/loop-guard/`).
