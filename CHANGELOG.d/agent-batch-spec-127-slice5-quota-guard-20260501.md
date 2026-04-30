---
version_bump: minor
section: Added
---

### Added

#### SPEC-127 Slice 5 IMPLEMENTED — Quota / budget guard (advisory, never blocks)

- `scripts/savia-quota-tracker.sh` — tracker genérico provider-agnostic. Lee `budget_kind` (`req-count` / `token-count` / `dollar-cap` / `none`) y `budget_limit` desde `~/.savia/preferences.yaml` (Slice 1 source-of-truth). 5 subcomandos:
  - `record <event-json>` — append JSONL event, valida JSON pre-write, silent skip cuando `budget_kind: none`.
  - `summary` — MTD consumption (events count + total + % usado vs límite), parseado en Python (graceful sobre líneas malformadas).
  - `threshold` — emite marker textual: `none` / `under-70` / `over-70` / `over-85` / `over-95` / `exceeded`.
  - `reset --confirm` — borra log (rejected sin --confirm; idempotente sobre log inexistente).
  - `status` — one-line resumen: `kind=X limit=Y threshold=Z`.
  - Storage: `~/.savia/quota/$USER.jsonl` (N3, gitignored, never repo-committed).
  - PV-06: cero hardcoded vendors. Branches en `budget_kind` declarado por usuario.

- `.claude/hooks/savia-budget-guard.sh` — PreToolUse advisory hook. **SIEMPRE exits 0** (never blocks). Drains stdin sin parsear (no inspecciona tool name/args). Records 1 request unit per call via tracker. Lee threshold marker; si over-70/85/95/exceeded, emite stderr nudge once-per-threshold-per-session vía `/tmp` marker keyed por PID + threshold. Bail silent si tracker falta.

#### Tests de regresión

- `tests/structure/test-spec-127-slice5-quota-guard.bats` — 40 tests certified. Estructura por AC:
  - **AC-5.1 ×7**: tracker exists/executable/syntax + lee budget_kind from preferences + 'record' append JSONL + rechaza JSON inválido + missing arg → exit 2 + summary computa MTD
  - **AC-5.2 ×8**: threshold under-70 cuando vacío + over-70 al 75% + over-85 al 90% + over-95 al 96% + exceeded al >100% + hook exists/executable/syntax + ALWAYS exits 0 + warns to stderr at over-70 + idempotency per-session
  - **AC-5.3 ×5**: status sin preferences kind=unset + record silent skip cuando none + record silent skip cuando unset + summary muestra idle + threshold "none" + hook silent stderr
  - **reset ×3**: rejects sin --confirm + deletes con --confirm + missing log graceful
  - **PV-06 ×3**: tracker sin vendors + hook sin vendors + tracker branches on budget_kind no en SAVIA_PROVIDER comparison
  - **Negative + edge ×4**: unknown subcommand → exit 2, zero-arg → exit 2, empty log → 0 events, malformed JSONL skipped no crash, hook with missing tracker silent
  - **Spec ref ×3**: SPEC-127 ref + tracker references Slice 5 + hook references Slice 5
  - **Coverage ×3**: 5 subcommands defined + 5 threshold states + hook never blocks (exit 0 + "NEVER block" comment)

### Why this matters

Algunos providers (vendor-managed con cuota mensual) queman premium requests más rápido de lo que el operador espera — caso típico: tool attachments inflan la cuenta de requests sin que el usuario lo vea hasta que es demasiado tarde. Otros providers (LocalAI, Ollama, self-hosted) no tienen cuota y el tracker debe ser invisible. Slice 5 hace ambas cosas: cuando hay cuota declarada, mide y avisa con thresholds escalonados (70% temprano, 95% urgente); cuando no hay cuota, skip silencioso. PV-02 cumplido — el hook **nunca bloquea**, solo avisa, así que ni en peor caso una sesión se rompe por el guard.

### Hard safety boundaries

- **PV-01 Backward compat absoluto**: cero modificación de los 64 hooks, 70 agents, 90 skills, 534 commands existentes. Solo se añade el tracker + hook nuevos.
- **PV-02 No blocks**: el hook PreToolUse **SIEMPRE exits 0**, never blocks. Verified by BATS regression.
- **PV-03 Zero data exfiltration**: log local en `~/.savia/quota/`, never repo-committed (gitignored). No telemetry to any vendor.
- **PV-04 Operator opt-in**: si el usuario no declara `budget_kind` o lo deja en `none`, tracker invisible.
- **PV-06 No vendor lock-in**: BATS tests verifican que ni tracker ni hook mencionan vendors comerciales hardcoded.
- Cero red, cero git operations en runtime, cero merge autónomo.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-127-slice5-quota-guard-20260501`, sin merge autónomo.

### Spec ref

SPEC-127 (`docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md`) → Slice 5 IMPLEMENTED 2026-05-01. AC-5.1, AC-5.2, AC-5.3 cumplidos. Con esto SPEC-127 tiene Slices 1, 2a, 4, 5 implementados — quedan Slice 2b (TS plugin top hooks portados, requires Node toolchain OK) y Slice 3 (MCP server slash commands, requires Node toolchain OK).
