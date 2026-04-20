# SPEC-068: Hook Enhancement — PreCompact, PostCompact, PostToolUseFailure

**Status**: Approved | **Date**: 2026-04-01 | **Era**: 165

---

## Problem

Three hooks exist but do minimal work:
- `pre-compact-backup.sh`: Only regex grep for decisions. No tier classification (SPEC-016).
- `post-compaction.sh`: Reads memory-store but ignores session-hot context.
- `post-tool-failure-log.sh`: Unstructured JSONL logging. No categorization or retry hints.

## Solution

### 1. PreCompact: Tier A/B/C Classification (SPEC-016)

Add tier classification before compact:
- **Tier A (ephemeral)**: line numbers, temp paths, debug output → DISCARD
- **Tier B (session-hot)**: decisions, corrections, current task → PERSIST to session-hot.md
- **Tier C (permanent)**: lessons, conventions → PERSIST to memory-store.sh

Output summary to stdout (visible to Claude post-compact).

### 2. PostCompact: Session-Hot Reinjection

Read `session-hot.md` after compaction and print as first section of reinjected memory. This provides session continuity across compactions. Truncate session-hot.md after consumption.

### 3. PostToolUseFailure: Structured Error Categorization

Categorize errors into 6 buckets with retry hints:
- `permission`: EACCES, not authorized → check permissions
- `not_found`: ENOENT, no such file → verify path
- `timeout`: ETIMEDOUT → retry or increase timeout
- `syntax`: parse error → review input syntax
- `network`: ECONNREFUSED → check connectivity
- `unknown`: fallback → log for analysis

Track repeated failures (3+ same tool/day) → flag as pattern.

## Files

| File | Action | Lines |
|------|--------|-------|
| `.claude/hooks/pre-compact-backup.sh` | ENHANCE | 45→~90 |
| `scripts/post-compaction.sh` | ENHANCE | 139→~145 |
| `.claude/hooks/post-tool-failure-log.sh` | ENHANCE | 21→~70 |
| `tests/hooks/test-hook-enhancements.bats` | NEW | ~90 |

## Non-Goals

These Claude Code hook events do NOT exist yet:
- **FileChanged** — would enable live config reload
- **InstructionsLoaded** — would enable dormant rules audit
- **PermissionRequest** — would enable auto-approve patterns

Marked as future feature requests to Anthropic. Not implemented.

## Acceptance Criteria

- PreCompact: Tier B items written to session-hot.md, Tier A discarded
- PostCompact: session-hot.md content appears as first section, file truncated after
- PostToolUseFailure: JSONL entries contain `category` and `retry_hint` fields
- All enhanced hooks ≤ 150 lines
- 8 BATS tests pass
- Empty input handled gracefully (exit 0) in all hooks
