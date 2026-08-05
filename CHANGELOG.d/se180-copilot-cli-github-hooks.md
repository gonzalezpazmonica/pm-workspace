---
version_bump: minor
section: Added
---

### Added

- SE-180: `.github/hooks/savia.json` generated from `.claude/settings.json` via `scripts/generate-github-hooks.sh` — hook support for GitHub Copilot CLI (>=1.0.60), which does not read `.claude/settings.json` directly (only `.github/hooks/*.json` from gitRoot). Single launcher `run-savia-hook.sh` (no env vars, no inline shell) and `wrap-for-copilot.sh` translates the Claude→Copilot output schema. Partial coverage: only the 9 event types documented in Copilot's hook schema have an equivalent (~83 of 110 hook entries translate; the rest are skipped for unmapped events, non-HTTPS webhook, or non-standard command formatting — see spec for the full breakdown). Structure and schema validated (bats 6/6) — live empirical validation against Copilot CLI itself confirmed for PreToolUse blocking only; SessionStart/agentStop still pending (see runbook).
