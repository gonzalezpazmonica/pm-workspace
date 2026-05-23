# Provenance — anthropic-skills

**Upstream**: https://github.com/anthropics/skills
**License**: Apache-2.0 (see each subdir's LICENSE.txt)
**Vendored**: 2026-05-23 (overnight-20260523, SPEC-145)
**Method**: `git clone --depth 1`, copied `skill-creator/` and `mcp-builder/`.
**Local patches**: none.

## Why vendored, not imported as workspace skill

See `external/README.md`. Upstream SKILL.md files exceed pm-workspace's
150-line cap (Rule #11) by design. Vendoring preserves upstream fidelity.

## Re-sync policy

Manual on-demand. Check upstream for breaking changes before re-syncing.
A scripted sync is tracked in SPEC-145 follow-up (not yet shipped).
