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
- **SE-313 S1/S2/S3/S4/S5 (telemetría estándar)**: `config/telemetry-schema.json`
  (schema `savia.event/1.0` validable), `config/telemetry-policies.yaml`
  (retención ≥180d Art. 26(6), rotación 10k líneas, sampling tail, redacción),
  `scripts/savia-trace.sh` (contexto W3C traceparent + jerarquía de spans),
  `scripts/telemetry-tail-sample.sh` (rotación/retención/redacción),
  `scripts/trace-export-otlp.sh` (export OTLP opt-in, zero telemetry by default),
  `scripts/telemetry-report.sh` (informe estático S8). Hooks `session-init`,
  `subagent-lifecycle`, `task-lifecycle`, `agent-trace-log` emiten eventos
  estándar con modelo real (`savia_resolve_model`) y agente real (fin de
  `agent:"unknown"`). Redacción: `SAVIA_TELEMETRY_REDACT=1` degrada a solo
  `{ts,event}`; paths absolutos → `{project}`; session_id truncado a 8 chars.
- **SE-313 S6 / SE-275 S1+S3 (audit trail)**: `scripts/audit-chain-append.sh`
  (hash-chained con HMAC local), `scripts/audit-chain-verify.sh` (detecta
  tampering: entry modificado, seq salto, firma rota), `scripts/audit-chain-prune.sh`
  (rotación >90d). Integrado en court-orchestrator, truth-tribunal-orchestrator,
  recommendation-tribunal-orchestrator y dev-orchestrator (`.opencode/` y
  `.claude/`); `agent-notes-protocol.md` con requirement de Result Envelope.
- **SE-314 (clasificador determinista)**: `scripts/sovereignty-classify.sh`
  (reemplaza a `ollama-classify.sh` como API pública; este queda como shim que
  delega). Capa 1 determinista (aws/github/openai/connection/private-key/dni/
  internal-ip → BLOCK sin LLM), Capa 2 LLM con seed=42 + top_k=1 + format=json +
  num_predict=32 (determinismo), caché por hash con TTL e invalidación por
  modelo/prompt. `config/classifier/prompt-v2.txt` (prompt versionado con
  allowlist de sujetos técnicos), `config/sovereignty-thresholds.yaml`
  (umbrales por destino n1/n4 + hard_block_rules), `scripts/sovereignty-decide.sh`
  (decisión por confidence, no etiqueta binaria). Gates TS y bash integrados
  (paridad AC-S5.1); evento `classifier.block`/`classifier.verdict` en
  telemetría; `scripts/classifier-fp-report.sh` (reporte mensual de FP).
  Corpus de regresión `tests/evals/classifier-corpus.json` (22 casos) con
  runner `scripts/classifier-corpus-run.sh` (22/22 pass; caso real
  savia-env.sh ahora PUBLIC, antes CONFIDENTIAL 10/10).
- **Tests nuevos**: `tests/test-savia-trace.bats`, `tests/test-telemetry-tail-sample.bats`,
  `tests/test-audit-chain.bats`, `tests/test-sovereignty-classify.bats`,
  `tests/test-sovereignty-s5.bats`.

### Fixed

- **Bug de comparación float en el clasificador**: `[[ "$LLM_CONF" -ge 0.70 ]]`
  es aritmético en bash y falla con decimales (0.9 → error → degradaba todo a
  PUBLIC). Ahora se compara con python (`ge()`). El caso `pii-email-name`
  (confidential 0.9) volvía public; corregido.
- **Bug de `--` en la función `detect`**: `detect "private_key" -- 'patrón'`
  usaba `--` como patrón (grep matcheaba líneas con guiones). Ahora el `--` se
  trata como separador y `grep -E --` respeta patrones que empiezan por `-`.
- **Corpus-run**: fragmentos de secretos construidos en runtime (nunca
  literales en el script) para evitar bloquearse a sí mismo en los gates.

- `isShieldScript` (sovereignty-patterns.ts) y whitelist del gate bash ahora
  reconocen `sovereignty-classifier` y `SE-314` como self-reference editable.
- **Guard de dispatch silencioso**: `dispatch-trace.ts` y `subagent-audience-filter.ts`
  leían `input.args` (siempre vacío en el contrato real de OpenCode, donde los args
  llegan en `output.args`) y el parámetro `_output` impedía acceder a `output`. El
  resultado era que la telemetría de dispatch nunca se escribía en runtime pese a
  funcionar en tests. Corregido: el guard lee `output.args` con fallback a
  `input.args` (shape legacy/Claude Code). Tests TS actualizados al contrato real
  (`input.tool` + args en output). Verificado con node:test shim: 6/6.
