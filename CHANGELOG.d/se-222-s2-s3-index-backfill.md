# SE-222 S2+S3 — index.md auto-generado + resource: back-fill

Date: 2026-06-24

## S2 — index.md auto-generado

- scripts/generate-propuestas-index.sh: scans docs/propuestas/, generates sorted Markdown table.
  Mode --check exits 1 if stale.
- docs/propuestas/index.md: generated (317 specs).
- .opencode/hooks/propuestas-index-refresh.sh: PostToolUse hook, rate-limited 60s.
- .claude/settings.json: hook registered under PostToolUse Edit|Write matcher.

## S3 — resource: back-fill en 18 ficheros

Added resource: URI in frontmatter of 18 files (19 total incl. SE-222 which already had it).
All URIs are http/https or internal:// format. No duplicates.
autonomous-safety.md skipped: no frontmatter.

## Tests

- tests/test-generate-propuestas-index.bats: 13 tests, all pass
- tests/test-resource-uri-backfill.bats: 9 tests, all pass
