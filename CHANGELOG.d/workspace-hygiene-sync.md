---
version_bump: patch
section: Fixed
---

### Fixed

- `skill-catalog-audit.sh`: parsea YAML plegado (`description: >` multilinea) — antes marcaba `bus-factor-analysis` y `context-dome` como `description-too-short` (FAIL) y rompia la suite BATS FULL en cualquier PR.
- Contadores en sync: `CLAUDE.md` (commands 566→567, skills 124→125), `docs/rules/domain/pm-workflow.md` y `docs/RESOLVER.md` — el drift rompia `claude-md-drift-check` y `readiness-check` (y el readiness stamp).
