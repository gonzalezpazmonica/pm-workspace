---
version_bump: minor
section: Added
---

### Added

- **SE-313 S7 — Dispatch de subagentes con tiers corregido**: `~/.savia/preferences.yaml`
  usa IDs de modelo con prefijo de provider (`deepseek/deepseek-v4-pro`);
  `opencode.json` pasa de IDs rotos a tier names (`heavy|mid|fast`) que el plugin
  `savia-foundation.ts` traduce; `savia_resolve_model` auto-prefija como red de
  seguridad. Elimina el fallo silencioso `Model not found: <id>/.` en subagentes.
- **Telemetría de dispatch**: nuevo `scripts/otel-emit.sh` (schema `savia.event/1.0`,
  trace_id W3C), `scripts/subagent-dispatch-gate.sh` (gate bash, deriva tier del
  frontmatter del agente), guard `dispatch-trace.ts` (OpenCode nativo), y
  `config/model-registry.json` (caché de `opencode models`). El hook
  `agent-dispatch-validate.sh` instrumenta cada dispatch → eventos
  `dispatch.resolved|dispatch.failed` en `output/telemetry-events.jsonl`.
- **Specs**: `SE-313` (observabilidad/trazabilidad OTel GenAI + EU AI Act, 8 slices)
  y `SE-314` (rediseño determinista del clasificador de soberanía, 5 slices).
- **Tests**: `tests/test-otel-emit.bats`, `tests/test-subagent-dispatch-gate.bats`,
  `__tests__/dispatch-trace.test.ts`.

### Fixed

- `isShieldScript` (sovereignty-patterns.ts) y whitelist del gate bash ahora
  reconocen `sovereignty-classifier` y `SE-314` como self-reference editable.
- **Guard de dispatch silencioso**: `dispatch-trace.ts` y `subagent-audience-filter.ts`
  leían `input.args` (siempre vacío en el contrato real de OpenCode, donde los args
  llegan en `output.args`) y el parámetro `_output` impedía acceder a `output`. El
  resultado era que la telemetría de dispatch nunca se escribía en runtime pese a
  funcionar en tests. Corregido: el guard lee `output.args` con fallback a
  `input.args` (shape legacy/Claude Code). Tests TS actualizados al contrato real
  (`input.tool` + args en output). Verificado con node:test shim: 6/6.
