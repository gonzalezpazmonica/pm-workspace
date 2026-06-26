# SPEC-182 — Bitemporal `timeline:` frontmatter

**Date:** 2026-06-24  
**Spec:** SPEC-182  
**Status:** IMPLEMENTED

## What was added

### `scripts/spec-timeline-append.py`

New script that appends a bitemporal entry to the `timeline:` array in a
spec's YAML frontmatter.

- Creates `timeline:` key if absent.
- Preserves all other frontmatter fields unchanged.
- `--dry-run` flag for preview without write.
- No external dependencies (stdlib only).

### `scripts/spec-timeline-query.py`

New script that queries `timeline:` arrays across one or many spec files.

- `--file` or `--dir` (scans `*.md`).
- Filters: `--status`, `--learned-after`, `--at` (point-in-time).
- Output formats: `table`, `json`, `csv`.
- No external dependencies (stdlib only).

### `scripts/spec-lifecycle.sh` — extended

- `--no-timeline` flag: skips the auto-append step.
- On every status transition, automatically calls `spec-timeline-append.py`
  with `source=spec-lifecycle:auto` (unless `--no-timeline` is passed).

### Back-fill (10 specs)

Timeline entries (`value=IMPLEMENTED, from=2026-06-24, learned=2026-06-24,
source=session:2026-06-24`) added to:

- SPEC-192, SPEC-193, SPEC-194, SPEC-189, SPEC-187
- SPEC-149, SPEC-199, SPEC-163, SPEC-164, SE-222

## Tests

- `tests/scripts/test_spec_timeline.py` — 13 pytest tests (all pass)
- `tests/bats/test-spec-timeline.bats` — 8 bats tests (all pass)
