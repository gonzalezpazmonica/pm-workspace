---
version_bump: minor
section: Added
---

### Added

#### SPEC-127 — Savia ↔ OpenCode + GitHub Copilot Enterprise compatibility

- `docs/propuestas/SPEC-127-savia-opencode-copilot-enterprise-compat.md` — APPROVED 2026-04-30 (operator review). Audit Savia ↔ OpenCode + GitHub Copilot Enterprise. 5 slices (Foundation 8h · Hook adapter+TS plugin 16-20h · Slash command MCP shim 12-16h · Subagent fallback 8-12h · Premium quota guard 6h ≈ 50-62h total). Documents 5 critical frictions (compaction #11157, hooks port bash→TS plugin, GHE on-prem auth #3936, premium request inflation #8030, context cap 128K #5993) + 3 categorical breaks vs OpenCode-Claude (zero hook surface, no subagent fan-out, no workspace slash commands). Restricciones inviolables PV-01 a PV-05.

#### SPEC-127 Slice 1 IMPLEMENTED — Provider-agnostic foundation

- `scripts/savia-env.sh` — provider-agnostic env loader. Sourceable from any hook. Exports `SAVIA_WORKSPACE_DIR` (fallback chain `SAVIA_WORKSPACE_DIR → CLAUDE_PROJECT_DIR → OPENCODE_PROJECT_DIR → git rev-parse → pwd`) y `SAVIA_PROVIDER` (`claude | copilot | localai | <opencode-provider> | unknown`). Capability probes `savia_has_hooks` y `savia_has_slash_commands` para degradación graceful bajo Copilot Enterprise (zero hook surface). CLI dispatch standalone (`bash scripts/savia-env.sh print|workspace|provider|has-hooks|has-slash-commands`).
- `docs/rules/domain/provider-agnostic-env.md` — rule doc. Define el contrato de SAVIA_WORKSPACE_DIR + SAVIA_PROVIDER. Tabla cross-frontend (Claude Code / OpenCode-Claude / OpenCode-Copilot / LocalAI). Hook author + script author checklists. Backward compat absoluto (PV-01).
- `docs/rules/domain/model-alias-table.md` — tabla de mapeo canonical Claude → Copilot primary + fallback + LocalAI emergency. 3 rows canonical (`claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5-20251001`) con razones por mapping (capability cliff, cost caveat #8030, fallback chain). Marcada como provisional hasta confirmación operador del plan Copilot Enterprise concreto.
- `scripts/copilot-instructions-generate.sh` — generador idempotente de `.github/copilot-instructions.md` desde `.claude/agents/*.md` + workspace rules. Modes: `--generate` (stdout), `--apply` (write), `--check` (drift detection). Truncación automática a 120 líneas (AC-1.3). Trinity: CLAUDE.md ↔ AGENTS.md ↔ copilot-instructions.md desde misma source-of-truth.
- `.github/copilot-instructions.md` — Copilot canonical context (90 líneas, 0 `@import`s). Documenta project identity, inviolable rules (PV-01-05), reduced surface caveats (no hooks, no Task fan-out, no slash), premium request hygiene (#8030), conventions, agent table truncated.
- `.claude/hooks/agents-md-auto-regenerate.sh` — extendido para regenerar también copilot-instructions.md cuando agents change. Trinity stays in sync.

#### Tests de regresión

- `tests/structure/test-spec-127-slice1-foundation.bats` — 50 tests certified. Estructura por AC:
  - **AC-1.1 ×20**: savia-env.sh exists/executable/syntax + 4 fallback chain probes + 4 provider detection + 2 capability probes + CLI dispatch + provider-agnostic-env.md presence + 150-line cap + fallback chain documented
  - **AC-1.2 ×7**: model-alias-table.md exists + 150-line cap + 3 canonical rows + Copilot mappings + fallback rationale + LocalAI/SPEC-122 link + pending operator confirmation block
  - **AC-1.3 ×13**: copilot-instructions-generate.sh exists/executable/syntax + --check idempotency + --check drift detection + .github/copilot-instructions.md exists + 120-line cap + zero @imports + Project identity / Inviolable rules / Reduced surface / Agents sections + --apply twice idempotent
  - **Spec ref ×3**: SPEC-127 status APPROVED + slice_1_status IMPLEMENTED + ref in test file
  - **Edge ×4**: empty environment fallback / unknown provider boundary / nonexistent AGENTS_DIR / well-formed markdown boundary
  - **Coverage ×3**: 4 capability functions / 3 modes / 120-line cap enforcement

### Why this matters

Mónica acaba de obtener autorización corporativa para usar Savia con OpenCode + GitHub Copilot Enterprise. Sin Slice 1 (Foundation), arrancar Copilot empezaba con 64 hooks rotos en silencio (todos hard-codean `CLAUDE_PROJECT_DIR`) + 70 agentes con model IDs Claude-only + cero context para Copilot. Slice 1 corrige los tres asuntos en 8h sin tocar el comportamiento bajo Claude Code (PV-01 backward compat absoluto).

### Hard safety boundaries

- **PV-01 Backward compat absoluto**: cero modificación de los 70 agents, 64 hooks existentes, 90 SKILL.md, 534 commands. Solo se añade infraestructura nueva.
- **PV-04 Opt-in per-comando**: `SAVIA_PROVIDER=copilot` es operator-only. Por defecto, Savia sigue corriendo en Claude Max.
- Hook auto-regenerate extendido pero NO blocking — fallback graceful si script ausente.
- Cero red, cero git operations en runtime.
- Tabla de modelos marcada provisional — Slice 2 ramps requiere confirmación humana del plan Copilot real.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-127-savia-opencode-copilot-compat-20260430`, sin merge autónomo, AUTONOMOUS_REVIEWER asignado.

### Spec ref

SPEC-127 (`docs/propuestas/SPEC-127-savia-opencode-copilot-enterprise-compat.md`) → APPROVED 2026-04-30 + Slice 1 IMPLEMENTED 2026-04-30. Próximo Slice 2 (Hook adapter + TS plugin port, 16-20h) — bloqueado en 5 decisiones operador documentadas en spec §"Decisiones pendientes" (stack GHE, modelos disponibles, política MCP, presupuesto premium, granularidad sovereignty switch).
