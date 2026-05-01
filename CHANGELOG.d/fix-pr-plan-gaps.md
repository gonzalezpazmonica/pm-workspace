## [6.14.2] — 2026-05-01

Era 64 — Fixes: pr-plan pipeline gaps + CI breakage from provider-agnostic migration.

### Fixed
- `push-pr.sh`: title extraction changed from `tail -1` to `head -1` with sign/merge commit filtering — PR titles now use the most recent meaningful commit instead of the oldest sign commit.
- `push-pr.sh`: sign commit message no longer hardcodes `Co-Authored-By: Claude Opus 4.7` — PV-06 compliant.
- `push-pr.sh`: removed `Generated with Claude Code` footer from PR body — PV-06 compliant.
- `pr-plan.sh`: removed duplicate sign step — eliminates 2-3 sign commits per PR execution.
- `CLAUDE.md`: skills count updated 90 → 92 (drift check).

### Added
- `.claude/skills/savia-identity/DOMAIN.md` — domain documentation for workspace identity skill.
- `.claude/skills/savia-memory/DOMAIN.md` — domain documentation for persistent memory skill.

### Changed
- `tests/test-advisor-config.bats`: added `SAVIA_MODEL_HEAVY/MID/FAST` env vars in setup() to simulate configured preferences.yaml — tests adapt to provider-agnostic tier resolution.
- `SKILLS.md`: regenerated to include 2 new skills (92 total).
- `.claude/commands/pr-plan.md`: gate count updated 11 → 15 (G0-G14).
