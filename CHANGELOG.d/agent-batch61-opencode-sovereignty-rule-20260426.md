## [6.12.0] — 2026-04-26

Batch 61 — OpenCode sovereignty: SE-077 + SE-078 specs APPROVED + nueva regla obligatoria + G12 gate.

### Added
- `docs/propuestas/SE-077-opencode-replatform-v114.md` — APPROVED. 2 slices: plugin TS savia-gates (M, 8h) + parity audit ratchet (M, 6h). Era 189.
- `docs/propuestas/SE-078-agents-md-cross-frontend.md` — APPROVED. AGENTS.md generator + drift check + Stop hook auto-regenerate. M 6h, era 189. Supersedes SPEC-114.
- `docs/rules/domain/spec-opencode-implementation-plan.md` — regla canónica. Cada spec APPROVED post-2026-04-26 incluye sección obligatoria. Grandfathering documentado. Hot-fix exemption con `exempt_opencode_plan` frontmatter.
- `scripts/spec-opencode-plan-audit.sh` — audit script (3 sub-secciones obligatorias, exit 1 si missing).
- `scripts/pr-plan-gates.sh:g_opencode_plan` — G12 gate, solo se activa si el PR toca specs.
- `.ci-baseline/spec-opencode-plan-violations.count` — baseline frozen at 0.

### Changed
- `scripts/pr-plan.sh` — invoca G12 tras G11.
- `docs/propuestas/SE-074-parallel-spec-execution.md` — añade sección OpenCode Implementation Plan (PURE_BASH) + nuevo Slice 1.5 (S, 3h) "Adaptive halting + dynamic retry budget" inspirado en Kohli et al. 2026 (arXiv:2604.07822). Doble criterio halting (convergencia + confianza) + Poisson-clipped budget según effort field.
- `docs/ROADMAP.md` Era 189 inaugurada con SE-077 + SE-078 priority alta.
- `CLAUDE.md` — referencia lazy a la regla nueva.

### Context
Decisión estratégica de la usuaria 2026-04-26: Anthropic restringe Claude Code (Pro → Max-only). Soberanía técnica = compatibilizar con OpenCode v1.14 desde origen, no como retrofit. Inversión Slice 1 SE-077 (~8h) compra opción real de switch sin perder workspace.

Version bump 6.11.0 → 6.12.0.
