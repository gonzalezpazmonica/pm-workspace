# SPEC-190 — Application Code Twin (ACT) — MVP Implementation

**Date**: 2026-06-24
**Status**: IMPLEMENTED
**Spec**: SPEC-190 · Tier 1A · Era 199

## Summary

MVP implementation of the Application Code Twin (ACT) system. Delivers the
core scripts and documentation needed to represent application code behaviour
as structured Markdown files (CTFs) for agent-assisted development.

## Files Added

| File | Purpose |
|---|---|
| `scripts/code-twin-generate.py` | Generates CTFs from single source files (Python, TypeScript, C#) |
| `docs/rules/domain/code-twin-protocol.md` | Canonical protocol doc — CTF format, usage rules, anti-patterns |
| `tests/scripts/test_code_twin.py` | pytest suite: 10 tests covering generate, sync-check, manifest |
| `tests/bats/test-spec-190-code-twin.bats` | BATS suite: 27 tests covering all MVP deliverables |
| `CHANGELOG.d/spec-190-application-code-twin.md` | This file |

## Files Modified

| File | Change |
|---|---|
| `scripts/code-twin-init.sh` | Added `--project` / `--output` flags; generates `manifest.yaml` + `README.md`; auto-detects project language |
| `scripts/code-twin-sync-check.sh` | Added `--twin-dir` flag, `--json` output, structured JSON with `{total_ctfs, stale_count, fresh_count, stale_files}` |

## Pre-existing files (Slices 1–9 already implemented)

The following scripts were implemented in earlier slice PRs and verified
as passing their BATS suites during this implementation:

- `scripts/code-twin-lint.sh` (Slice 1)
- `scripts/code-twin-extract.py` (Slice 7)
- `scripts/code-twin-simulate.py` + `code-twin-simulate.sh` (Slice 5)
- `scripts/code-twin-validate-spec.py` + `code-twin-validate-spec.sh` (Slice 6)
- `scripts/code-twin-load.sh` (Slice 8)
- `scripts/code-twin-anonymize.sh` (Slice 8)
- `.opencode/agents/code-twin-agent.md` (Slice 8)

## Acceptance Criteria Coverage (MVP)

| AC | Status | Notes |
|---|---|---|
| init.sh generates manifest.yaml | ✓ | manifest has version, created, project, language, modules |
| init.sh generates README.md | ✓ | Usage guide with directory layout |
| init.sh accepts --project/--output flags | ✓ | Backward-compatible; positional arg still works |
| init.sh does not fail on empty project dir | ✓ | Handles empty directory cleanly |
| sync-check --json outputs structured data | ✓ | {total_ctfs, stale_count, fresh_count, stale_files} |
| sync-check --twin-dir flag | ✓ | Alternative to positional argument |
| sync-check exit 0 on empty dir | ✓ | No CTFs = all fresh = exit 0 |
| sync-check exit 1 on stale CTFs | ✓ | stale_count > 0 → exit 1 |
| generate.py produces CTF with frontmatter | ✓ | All 8 required fields present |
| generate.py: Python import detection | ✓ | Imports visible in depends_on |
| generate.py: C# support | ✓ | Class + method names + namespace→layer |
| generate.py: TypeScript support | ✓ | @Injectable→application, @Controller→api, @Component→frontend |
| code-twin-agent.md present | ✓ | Pre-existing from Slice 8 |
| code-twin-protocol.md present | ✓ | New — canonical doc with CTF format, anti-patterns |

## Test Results

```
pytest tests/scripts/test_code_twin.py -q  →  10/10 passed
bats tests/bats/test-spec-190-code-twin.bats  →  27/27 passed
```
