## [6.14.1] — 2026-05-01

Era 64 — Provider-agnostic migration: Heavy/Mid/Fast tiers replacing hardcoded model IDs.

### Changed
- Model names migrated from hardcoded IDs (`claude-opus-4-7`, `claude-sonnet-4-6`) to provider-agnostic tiers (`Heavy`, `Mid`, `Fast`) resolved at runtime via `scripts/savia-env.sh` and `~/.savia/preferences.yaml`.
- `docs/AGENTS.md`: all agent tables and decision tree updated to tier-based labels.
- `.opencode/CLAUDE.md`: model constants replaced with runtime resolution note.
- `opencode.json`: agent definitions and slash commands populated with provider-agnostic config.
- `scripts/advisor-config.sh`: advisor/executor defaults sourced from preferences.
- `.claude/commands/agent-run.md`, `.claude/commands/pr-plan.md`: model references updated.

### Added
- `.claude/skills/savia-identity/SKILL.md` — workspace self-awareness skill.
- `.claude/skills/savia-memory/SKILL.md` — persistent memory management skill.
