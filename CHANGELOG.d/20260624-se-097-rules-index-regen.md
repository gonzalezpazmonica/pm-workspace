## SE-097 — Rules INDEX.md regeneration (2026-06-24)

### Added
- scripts/rules-index-generate.sh: generates docs/rules/INDEX.md from filesystem scan
  - Extracts: filename, H1/frontmatter title, context_tier, spec_id
  - Table sorted by context_tier (L1 first), then filename
  - Header: "# Rules Index — auto-generated YYYY-MM-DD · N rules"
  - --check mode: exit 1 if INDEX.md is stale
  - Excludes archived rules (archived: true in frontmatter)
- docs/rules/INDEX.md: regenerated — 233 active rules, 240 lines
- tests/bats/test-se-097-rules-index-regen.bats: 4 tests (all pass)

### Notes
- Existing docs/rules/domain/INDEX.md (165 lines, SPEC-115 format) is separate
  from the new docs/rules/INDEX.md (this spec). Both coexist.
- New INDEX.md uses 4-column table (context_tier | file | title | spec) vs old
  3-column (Cat | File | Description).
