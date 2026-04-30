---
version_bump: minor
section: Added
---

### Added

#### SPEC-127 Slice 4 IMPLEMENTED — Subagent fallback (single-shot mode)

- `scripts/savia-orchestrator-helper.sh` — bash helper provider-agnostic. Subcomandos:
  - `mode` — devuelve `fan-out` o `single-shot` según `savia_has_task_fan_out` (lee `~/.savia/preferences.yaml` o autodetect via savia-env.sh).
  - `inline-prompt <agent>` — extrae el system prompt de un agent file (strip frontmatter) para inlining en single-shot mode.
  - `wrap <agent> <output-file>` — envuelve el output raw del agent inlined en envelope JSON `{agent, mode: "single-shot", result}` para preservar el schema downstream.
  - `list-agents` — lista los agents disponibles para inlining.
  - PV-06 enforcement: cero hardcoded vendor names. Branches en capability (`has_task_fan_out`), no en vendor.
- `docs/rules/domain/subagent-fallback-mode.md` — patrón canonical "single-shot expanded prompt" (121 líneas). Documenta: por qué (4 orchestrators dependen de Task; sin fallback rompen silenciosamente bajo stacks sin Task tool), capability detection (savia_orchestrator_helper.sh mode), pseudocode del pivot, trade-offs explícitos (loss of context isolation, sequential vs parallel, shared memory between judges), context-wall mitigation via wrap envelope.
- 4 orchestrators críticos patched con sección compacta "## Fallback mode (SPEC-127 Slice 4)":
  - `.claude/agents/court-orchestrator.md` (120 líneas)
  - `.claude/agents/truth-tribunal-orchestrator.md` (147 líneas — compactada SE-067/SE-066 en bloque "## Policies" para liberar espacio)
  - `.claude/agents/recommendation-tribunal-orchestrator.md` (73 líneas)
  - `.claude/agents/dev-orchestrator.md` (117 líneas)
  - Cada uno declara: detect mode → si single-shot, NO Task — read inline-prompt, run inlined, wrap output, repeat. Schema unchanged.
  - 150-line cap respetado en los 4.

#### Tests de regresión

- `tests/structure/test-spec-127-slice4-subagent-fallback.bats` — 39 tests certified. Estructura por AC:
  - **AC-4.1 ×11**: helper exists/executable/syntax + mode probe (fan-out / single-shot / preferences override / safe default fallback) + 4 orchestrators declare Fallback mode section + 150-line cap on patched agents
  - **AC-4.2 ×4**: wrap produces valid JSON envelope + UTF-8 preservation + rejects nonexistent file (negative) + envelope schema {agent, mode, result} consistent across 3 sample agents
  - **AC-4.3 ×3**: inline-prompt strips frontmatter + rejects nonexistent agent + non-empty for real agents
  - **list-agents ×3**: ≥10 agents listed + 4 critical orchestrators present + missing AGENTS_DIR exits 3
  - **PV-06 ×2**: helper script + rule doc free of hardcoded vendor names
  - **Negative + edge ×5**: unknown subcommand → exit 2, zero-arg → exit 2, wrap missing args, empty agent file graceful, frontmatter-only agent returns zero output
  - **Rule doc structure ×4**: exists + ≤150 lines + documents single-shot pattern + lists 4 orchestrators + schema preservation
  - **Spec ref ×3**: slice_4_status: IMPLEMENTED + ref in test file + helper references SPEC-127
  - **Coverage ×3**: 4 subcommands defined + reads has-task-fan-out probe + wrap envelope keys

### Why this matters

Sin Slice 4, los 4 orchestrators críticos de Savia (`court`, `truth-tribunal`, `recommendation-tribunal`, `dev`) fallaban silenciosamente bajo cualquier stack sin Task tool. La salida sería cero o malformed JSON; los aggregators downstream (audit trail, gate aggregators, CI pipelines) no se enteran del problema. Slice 4 hace 3 cosas: detecta la capability en runtime, documenta el patrón single-shot expanded prompt (con trade-offs explícitos para no esconder la pérdida), y patcha los 4 orchestrators para que se adapten. Schema downstream preservado por el envelope `{agent, mode, result}`. PV-05 cumplido — la pérdida es visible.

### Hard safety boundaries

- **PV-01 Backward compat absoluto**: cero modificación del fan-out flow existente. Solo se añade el branch single-shot a los 4 orchestrators.
- **PV-05 Visibilidad de pérdidas**: trade-offs documentados explícitamente en el rule doc (loss of isolation, sequential not parallel, shared memory).
- **PV-06 No vendor lock-in**: helper bash branches en capability (`has_task_fan_out`), no en vendor. BATS test enforce.
- 150-line cap respetado en los 4 orchestrators tras patch.
- Cero red, cero git operations en runtime, cero merge autónomo.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-127-slice4-subagent-fallback-20260430`.

### Spec ref

SPEC-127 (`docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md`) → Slice 4 IMPLEMENTED 2026-04-30. AC-4.1, AC-4.2 cumplidos; AC-4.3 cumplido en BATS estructural (mode detection + envelope schema + inline-prompt). Equivalencia funcional real fan-out vs single-shot (output side-by-side) requires LLM harness — deferred a tests E2E. Próximo: Slice 5 (quota/budget guard, ~6h, bash-only) o Slice 2b/3 (TS plugin + MCP server) cuando confirmes que añadir Node toolchain al pipeline está OK.
