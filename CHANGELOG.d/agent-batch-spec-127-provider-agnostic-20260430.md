---
version_bump: minor
section: Added
---

### Added

#### SPEC-127 — Savia ↔ OpenCode provider-agnostic compatibility

- `docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md` — APPROVED 2026-04-30 (operator review). Renamed from prior Copilot-specific framing. Inference-independent foundation: cada usuario decide su frontend (Claude Code / OpenCode / Codex / Cursor / otro) y su provider (Anthropic API / hosted-OSS / LocalAI / Ollama / vendor-managed / custom corporate endpoint). Framework no asume vendor — detecta capacidades en runtime y degrada gracefully. 5 slices (Foundation 8h · Hook adapter 16-20h · Slash MCP shim 12-16h · Subagent fallback 8-12h · Quota guard 6h ≈ 50-62h). Restricciones inviolables PV-01 a PV-06 (PV-06 = cero vendor lock-in en source).

#### SPEC-127 Slice 1 IMPLEMENTED — Provider-agnostic foundation + onboarding

- `scripts/savia-env.sh` — provider-agnostic env loader. Sourceable. Exporta `SAVIA_WORKSPACE_DIR` (fallback chain `SAVIA_WORKSPACE_DIR → CLAUDE_PROJECT_DIR → OPENCODE_PROJECT_DIR → git rev-parse → pwd`) y `SAVIA_PROVIDER` (free-form: lo que el usuario declare en preferences.yaml). 3 capability probes: `savia_has_hooks`, `savia_has_slash_commands`, `savia_has_task_fan_out`. Cero hardcoded vendor names en source — los probes leen `~/.savia/preferences.yaml` cuando existe y autodetectan via env vars cuando no. CLI dispatch standalone.
- `scripts/savia-preferences.sh` — gestor de `~/.savia/preferences.yaml`. 6 subcomandos: `init` (entrevista 8 preguntas), `show`, `get <key>`, `set <key> <value>`, `reset --confirm`, `validate`. Validator rechaza claves prohibidas (`api_key`, `password`, `secret`, `token` — credenciales van en credential manager, no aquí).
- `.claude/commands/savia-setup.md` — slash command que invoca el onboarding interactivo. 8 preguntas con campo libre — sin lista cerrada de vendors. Re-ejecutable idempotentemente cuando el stack del usuario cambia.
- `docs/rules/domain/provider-agnostic-env.md` — rule canonical (121 líneas). Define el contrato cross-frontend × cross-provider. Hook author + script author checklists. Backward compat absoluto (PV-01).
- `docs/rules/domain/model-alias-schema.md` — schema YAML user-extensible (149 líneas, NO tabla cerrada). Cada usuario añade sus mappings en `~/.savia/preferences.yaml`. 3 ejemplos genéricos con placeholders (no nombran vendor concreto en source). Documenta forbidden credential keys.

#### Tests de regresión

- `tests/structure/test-spec-127-slice1-foundation.bats` — 55 tests certified (auditor max). Estructura por AC:
  - **AC-1.1 ×13**: savia-env.sh exists/executable/syntax + 4 fallback chain probes + CLI dispatch (print/workspace/unknown subcommand) + provider-agnostic-env.md presence + 150-line cap + fallback chain documented + capability probes documented
  - **AC-1.2 ×15**: preferences script exists/executable/syntax + 6 subcommands (set/get/show/reset/validate) + idempotency + reject without --confirm + reject forbidden keys + missing version detection + savia-setup command exists with frontmatter + ≤150 lines + references provider-agnostic
  - **AC-1.3 ×6**: schema doc exists + ≤150 lines + documents top-level YAML keys + forbidden credential keys + ≥3 stack examples + free-form/placeholder language
  - **AC-1.4 ×7**: preferences absent default + provider key wins over autodetect + has_hooks=no override + has_task_fan_out=yes override + explicit env wins + zero hardcoded vendor names in env script + zero hardcoded vendor names in preferences script
  - **Spec ref ×4**: SPEC-127 status APPROVED + slice_1_status IMPLEMENTED + ref in test file + PV-06 declared
  - **Edge ×4**: empty environment / unknown provider boundary / nonexistent prefs path / empty prefs file
  - **Coverage ×4**: 5 capability functions + 6 subcommands + _savia_pref helper + no vendor branching

### Why this matters

Savia hoy asume Claude Code: 64 hooks hard-codean `CLAUDE_PROJECT_DIR`, 70 agentes declaran `model: claude-X`. Cada usuario decide su stack — algunos seguirán con Claude Code, otros migran a OpenCode + provider OSS, otros usarán LocalAI on-prem, otros un endpoint corporativo custom. Slice 1 da el suelo común: el framework no asume nada, pregunta al usuario sus preferencias en onboarding (`/savia-setup`), persiste en `~/.savia/preferences.yaml` (per-user, never repo), y respeta esa declaración en runtime. Cero vendor lock-in: PV-06 verificado por tests.

### Hard safety boundaries

- **PV-01 Backward compat absoluto**: cero modificación de los 70 agents, 64 hooks, 90 SKILL.md, 534 commands existentes. Solo infraestructura nueva.
- **PV-03 Zero data exfiltration**: validator rechaza claves de credenciales en preferences.yaml.
- **PV-04 Opt-in**: si no hay preferences.yaml, Savia opera con defaults (Claude Code autodetect).
- **PV-06 No vendor lock-in**: BATS tests verifican que ni `savia-env.sh` ni `savia-preferences.sh` mencionan vendors comerciales específicos en código.
- Cero red, cero git operations en runtime.
- Onboarding 100% local: `~/.savia/preferences.yaml` nunca sale del home del usuario.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-127-provider-agnostic-20260430`, sin merge autónomo, AUTONOMOUS_REVIEWER asignado.

### Spec ref

SPEC-127 (`docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md`) → APPROVED 2026-04-30 + Slice 1 IMPLEMENTED 2026-04-30. Próximo Slice 2 (Hook portability classifier + critical TS plugin, 16-20h) — opera sobre el stack que el usuario haya declarado en preferences.
