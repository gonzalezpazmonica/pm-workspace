---
version_bump: minor
section: Changed
---

### Changed

- Zero vendor lock-in: 274 agent/command model declarations migrated from vendor-specific names (claude-opus/sonnet/haiku, opus/sonnet/haiku) to abstract capability tiers (heavy/mid/fast). Model resolution delegated to ~/.savia/preferences.yaml per-user, per-provider.
- SPEC-127 Slice 1: New scripts/savia-env.sh provider-agnostic environment loader with fallback chain for SAVIA_WORKSPACE_DIR and SAVIA_PROVIDER. Supports Claude Code, OpenCode, Copilot, and LocalAI via capability probes.
- 38 hooks now source savia-env.sh and export CLAUDE_PROJECT_DIR from SAVIA_WORKSPACE_DIR, fixing silent breakage under OpenCode where CLAUDE_PROJECT_DIR is unset.
- 4 missing hook timeouts added to settings.json (validate-bash-global, plan-gate, prompt-injection-guard, delegation-guard).
- Docs: model-alias-schema.md and model-alias-table.md rewritten for tier-based resolution. AGENTS.md and agents-catalog.md auto-regenerated.

