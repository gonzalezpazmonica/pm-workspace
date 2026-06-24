## SE-222-S2 — propuestas/INDEX.md auto-generator + PostToolUse hook (2026-06-23)

### Added

- scripts/propuestas-index-gen.sh — Generator that scans docs/propuestas/*.md, extracts frontmatter (spec_id, title, status, priority, effort, era), and writes docs/propuestas/INDEX.md grouped by status. Modes:
  - default — write INDEX.md
  - --dry-run — print to stdout, no file write
  - --check — exit 1 if INDEX.md is stale
- .claude/hooks/post-spec-edit-reindex.sh — PostToolUse hook that triggers regeneration when a file in docs/propuestas/*.md is edited (excluding INDEX.md and LOG.md themselves). Rate-limit: 1 regeneration per 60s (configurable via SAVIA_REINDEX_COOLDOWN). Toggle: SAVIA_PROPUESTAS_REINDEX_ENABLED=false.
- docs/propuestas/INDEX.md — Initial auto-generated index, sentinel-marked @generated.
- tests/test-propuestas-index-gen.bats — Tests for generator: dry-run, generate, check (passes when fresh, fails when stale), grouping by status, link rendering, exclusion of INDEX.md and LOG.md from listing.
- tests/hooks/test-post-spec-edit-reindex.bats — Tests for hook: empty/invalid input safe, only triggers on propuestas/*.md edits, skips INDEX.md/LOG.md self-edits, respects cooldown, toggle disables it.

### Changed

- .claude/settings.json — Register post-spec-edit-reindex.sh as PostToolUse hook on Edit|Write (matcher Edit|Write, async, timeout 5s).
- CLAUDE.md — Counter update: hooks 81→83, regs 84→86 (post-write-validate + dual-estimation-gate + new reindex hook).

### Rationale

SE-222 S2 third and final slice of Era 208 OKF Adoptable Patterns. Closes the OKF block (S0 resource: URI in #850, S1 LOG.md in #851, S2 INDEX.md in this PR). The hook integrates with the existing PostToolUse pipeline; isolation via SAVIA_HOOK_STATE_DIR for tests.

### Tests

- bats tests/test-propuestas-index-gen.bats: full suite passing
- bats tests/hooks/test-post-spec-edit-reindex.bats: full suite passing
- Both certified by test-auditor (>=80)

### Ref

- Spec: docs/propuestas/SE-222-okf-adoptable-patterns.md (Slice S2)
- Previous slices: PR #850 (S0 resource: URI), PR #851 (S1 LOG.md)
- Block closure: Era 208 OKF Adoptable Patterns
