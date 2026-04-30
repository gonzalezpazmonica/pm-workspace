---
version_bump: minor
section: Added
---

## [6.24.0] — 2026-04-30

Batch 85 — SPEC-107 Phase 1 IMPLEMENTED. AI Cognitive Debt Mitigation: telemetría conductual + hook hypothesis-first warning-only + comando `/cognitive-status` + guide doc. **OPT-IN por defecto (CD-04)** — los hooks ship instalados pero dormant hasta que la usuaria ejecuta `cognitive-debt.sh enable`. Phases 2 (friction hooks activos) y 3 (retrieval drill) follow-up.

### Added

#### Entry script

- `scripts/cognitive-debt.sh` — CLI principal con 5 subcomandos:
  - `enable`: añade hooks a `.claude/settings.json` (con backup), crea `~/.savia/cognitive-load/` mode 0700
  - `disable`: quita hooks de settings.json, preserva telemetría
  - `status`: muestra estado actual (ENABLED/DISABLED) + total events + today + log size + hooks instalados
  - `summary`: agrega últimos 7 días con histograma per-day + fast-accept ratio (<5s — proxy de skip-verification de Lee-MS/CMU 2025)
  - `forget --confirm`: borrado irreversible del telemetry log

#### Hooks (Phase 1 contract)

- `.claude/hooks/cognitive-debt-telemetry.sh` — PostToolUse async, registra cada Edit/Write/Task. Sin LLM call (CD-01), JSONL append en `~/.savia/cognitive-load/{user}.jsonl` (CD-03 N3), exit 0 siempre (CD-02 nunca bloquea).
- `.claude/hooks/cognitive-debt-hypothesis-first.sh` — PreToolUse **WARNING-ONLY en Phase 1**. Lee `git log -5`, si los últimos commits no tienen trailer `Hypothesis:` emite nudge a stderr (una vez por sesión vía `/tmp/marker`). Phase 2 escalará a soft-block con escape `--skip-cognitive`.

#### Command + guide

- `.claude/commands/cognitive-status.md` — wrapper de `cognitive-debt.sh status + summary` invocable como `/cognitive-status`.
- `docs/cognitive-debt-guide.md` — guía canónica:
  - Tesis (one paragraph): evidencia académica MIT/MS-CMU/CMU 2025 + Roediger-Karpicke
  - Tabla de componentes con estado (5 entregables)
  - Métricas computadas en Phase 1 (total events, fast-accept ratio, distribución por día)
  - Restricciones inviolables CD-01 a CD-04
  - Plan de Phase 2 + Phase 3 follow-up
  - Cross-refs SPEC-106, SPEC-125, SPEC-061, rules dom

#### Tests

- `tests/structure/test-cognitive-debt-phase-1.bats` — 38 tests certified. Cubre file-level safety×6, status×3, forget×3 (incluye boundary `--confirm` required), dispatch errors×3, telemetry hook (privacy + safety + edge cases)×5, hypothesis-first (warning-only enforcement)×4, restricciones CD-01 a CD-04 verificadas explícitamente×4, edge cases (missing dir, empty log)×3, doc + command×5, spec-ref + meta×2.

### Re-implementation attribution

Pattern source: own design from academic evidence (no clean-room re-implementation de proyecto externo). Cita literatura científica:
- Kosmyna et al. 2025 "Your Brain on ChatGPT" (arxiv.org/abs/2506.08872) — base para I4 telemetry necessity
- Lee et al. CHI 2025 (Microsoft Research + CMU) — base para fast-accept ratio como proxy de skip-verification
- CMU ICER 2025 (arxiv.org/pdf/2509.20353) — alerta sobre atrofia diferencial en metacognición débil
- Roediger & Karpicke 2006 — base para I1 hypothesis-first (retrieval practice)

### Acceptance criteria

#### SPEC-107 Phase 1 (5/5 — Slice 1 fully delivered)

- ✅ Phase 1.1 `scripts/cognitive-debt.sh` con 5 subcomandos (enable/disable/status/summary/forget)
- ✅ Phase 1.2 Hook telemetry async (I4) + comando `/cognitive-status`
- ✅ Phase 1.3 Hook hypothesis-first (I1) en modo **WARNING ONLY**, no bloquea (Phase 2 escalará)
- ✅ Phase 1.4 BATS tests certified
- ✅ Phase 1.5 Documentación: `docs/cognitive-debt-guide.md` con evidencia académica + Phase 2/3 deferred items

### Hard safety boundaries (autonomous-safety.md + spec CD-01 a CD-04)

- **CD-01** verificada por test: `! grep -qiE 'anthropic|/v1/messages|claude.api'` en los 3 scripts. Cero LLM calls.
- **CD-02** verificada por test: telemetry hook always `exit 0`, hypothesis hook always `exit 0` (Phase 1 warning-only).
- **CD-03** verificada por test: telemetry path en `~/.savia/cognitive-load/`, gitignored en N3.
- **CD-04** verificada por test: status muestra `DISABLED (opt-in default per CD-04)` por defecto.
- **Hooks NO añadidos a settings.json en este batch** — opt-in significa que la usuaria los activa con `cognitive-debt.sh enable` que hace el wire en settings.json (con backup).
- `set -uo pipefail` en first 5 lines en los 3 scripts (verificado por test contra el lint G5b).
- Cero red, cero git operations en los hooks.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-107-phase-1-...`, sin push automático ni merge.

### Spec ref

SPEC-107 (`docs/propuestas/SPEC-107-ai-cognitive-debt-mitigation.md`) → Phase 1 IMPLEMENTED 2026-04-30. Status spec: PROPOSED → IN_PROGRESS (Phase 1 done, Phases 2 + 3 follow-up). Critical Path post-audit item #2 cerrado. Próximo per ROADMAP.md §6: SPEC-SE-001 foundations (item #3, ~24h Slice 1) — entrada al roadmap principal Savia Enterprise por orden previo SPEC-125 → SPEC-107 → roadmap principal.
