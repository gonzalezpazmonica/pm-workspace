## [6.21.0] — 2026-04-26

Batch 70 — Era 189 OpenCode replatform — SE-077 Slices 1+2 + SE-078 IMPLEMENTED en un único PR. Cierra el bridge cross-frontend; pendiente E2E que la usuaria probará al bootear OpenCode.

### Added (SE-077 Slice 1 — OpenCode bridge plugin)
- `scripts/opencode-install.sh` — installer idempotente. Subcomandos: default install / `--version X.Y.Z` / `--link-only` / `--dry-run` / `--uninstall`. Crea `~/.savia/opencode/{bin,plugins}/`, descarga OpenCode v1.14.25 (vía official installer + npm fallback), enlaza el plugin `savia-gates`, escribe `opencode.json`, sella `.installed-version`.
- `scripts/opencode-plugin/savia-gates/` — plugin TypeScript (Bun runtime). Estructura:
  - `package.json` declara dep `@opencode-ai/plugin@^1.14.25`
  - `index.ts` exporta `SaviaGates` plugin con 7 handlers: `tool.execute.before/after`, `chat.message`, `permission.ask`, `command.execute.before`, `event` (mapping SessionStart/Stop/SubagentStop/TaskCreated/Completed), `experimental.session.compacting`
  - `lib/shell-bridge.ts` — lee `.claude/settings.json` (mismo origen que Claude Code) y construye event→hooks map; ejecuta los `.sh` originales SIN modificar via Bun's `$`
  - `lib/permission.ts` — AUTONOMOUS_REVIEWER policy: `permission.ask` retorna `deny` para destructive ops (`git push --force`, `git reset --hard`, `gh pr merge`, etc.) en branches `agent/*` o `spec-*`
  - `lib/audit.ts` — append-only JSONL en `~/.savia/audit/savia-gates.jsonl`
  - `lib/manifest.ts` — emite `manifest.json` sibling con bindings registrados (parity-audit lo lee, no parsea TS)
- `scripts/opencode-hooks/wrappers/safe-*.sh` (4 ficheros) — deprecation notice añadida en header. Eliminación tras 1 sprint de canary verde (Slice 2 AC-11 pendiente).

### Added (SE-077 Slice 2 — parity audit + canary)
- `scripts/opencode-parity-audit.sh` — Compara `.claude/settings.json` (Claude) vs `manifest.json` (OpenCode plugin). Subcomandos: default text / `--json` / `--baseline` / `--check`. Hooks pueden declarar `# opencode-binding: NOT_EXPOSED — <reason>` o `# opencode-binding: <handler> — ...` para excluirse del gap.
- `scripts/opencode-monthly-canary.sh` — Compara EQUIVALENCIA (no quality) entre ambos runtimes sobre 1 spec representativo. Auto-pick por frontmatter `canary_eligible: true`. Refusal con exit 4 si runtimes ausentes (CI-friendly via mocks).
- `.ci-baseline/opencode-parity-gap.count` — baseline pre-instalación commiteado (re-baselinear post-install).

### Added (SE-078 — AGENTS.md cross-frontend)
- `scripts/agents-md-generate.sh` — Generador idempotente. Subcomandos: default stdout / `--apply` (atomic write) / `--check` (drift detection exit 1). Sort agents alfabéticamente, trunca descripciones a 120 chars, escapa pipes para markdown table.
- `scripts/agents-md-drift-check.sh` — Wrapper sobre `--check` (sibling resolution sin depender de PROJECT_ROOT). Lo invocará pr-plan G14 en próxima iteración.
- `.claude/hooks/agents-md-auto-regenerate.sh` — Stop hook async. Detecta edits en `.claude/agents/` con `git status --porcelain`, regenera `AGENTS.md`, registra cambios en `output/agent-runs/agents-md-regen.log`. Registrado en `.claude/settings.json` Stop array.
- `AGENTS.md` (repo root) — generado con todos los agentes actuales.
- `docs/rules/domain/agents-md-source-of-truth.md` — regla canonical (62 líneas).

### Changed
- `docs/rules/domain/opencode-savia-bridge.md` — nueva regla canonical OpenCode↔Savia bridge (95 líneas).
- `docs/propuestas/SPEC-114-docs-savia-alignment.md` — flipped a `status: SUPERSEDED`, `superseded_by: SE-078`, banner añadido.
- `docs/propuestas/SE-077-...` y `docs/propuestas/SE-078-...` — frontmatter a `status: IMPLEMENTED`, ACs marcados `[x]` salvo AC-03/AC-05 (E2E E2E pending boot por la usuaria) y AC-11 (eliminación wrappers tras 1 sprint).

### Tests
- 5 ficheros nuevos, 80 tests, todos certified ≥80:
  - `test-agents-md-generate.bats` — 22 tests, score 88
  - `test-agents-md-drift-check.bats` — 8 tests, score 81
  - `test-opencode-parity-audit.bats` — 16 tests, score 85
  - `test-opencode-monthly-canary.bats` — 16 tests, score 83
  - `test-opencode-savia-gates-plugin.bats` — 22 tests, score 86
- Sin regresiones en orchestrator/merge-queue/G13/attention-anchor/db-sandbox/cleanup-stale.

### Hard safety boundaries
- Plugin TS NUNCA hace `git push`, `gh pr merge`, `git push --force`
- Installer NUNCA modifica el repo (sólo `~/.savia/`)
- Parity audit + canary son read-only por defecto (`--baseline` y `--check` requieren flag explícito)

### Spec ref
SE-077 + SE-078 → IMPLEMENTED (con boots E2E pendientes). Era 189 cierra su gate de implementación; el siguiente gate es operacional (Mónica boot OpenCode + verifica AC-03 SE-073 + AC-05 carga AGENTS.md).

### Pattern alignment (SE-080 Genesis)
- B8 ATTENTION ANCHOR: plugin re-inyecta `SPEC_WORKER_ID` y `Spec ref:` en cada hook payload, igual que Claude Code
- A9 SUPERVISED EXECUTION: `permission.ask` enforce AUTONOMOUS_REVIEWER deterministically antes de pedir al humano
