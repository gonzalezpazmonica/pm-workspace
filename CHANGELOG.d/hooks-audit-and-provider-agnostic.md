## [6.15.0] — 2026-05-01

Era 64 — Auditoría completa + provider-agnostic hardening del sistema de hooks.

### Fixed
- `validate-bash-global.sh`: `$CLAUDE_PROJECT_DIR` → fallback `${CLAUDE_PROJECT_DIR:-${OPENCODE_PROJECT_DIR:-$PWD}}` — antes era el único hook BROKEN sin fallback provider-agnostic.

### Changed
- `CLAUDE.md`: hooks count corregido → "65 hooks (61 registrados, 4 huérfanos)".
- `.claude/hooks/README.md`: catálogo completo de 65 hooks con categorías reales, documentación de arquitectura dual (OpenCode nativo + bridge), y compliance provider-agnostic.

### Added
- `docs/rules/domain/hook-event-equivalence.md`: tabla de mapeo Claude Code ↔ OpenCode (17 eventos), gap analysis (6 sin equivalente), documentación del bridge `savia-gates`, y roadmap de migración en 4 fases.
