---
context_tier: L1
token_budget: 311
---

# Write-Time Non-Blocking Validation

> Ref SPEC-184. Applied 2026-06-04.

## Idea

PostToolUse hook on Edit and Write for markdown files. Runs lightweight validators that warn to stderr but never block. The agent reads warnings the same turn and self-repairs without round-trip via commit-guardian.

## Hook

scripts path: .opencode/hooks/post-write-validate.sh
validators dir: .opencode/hooks/validators/

Always exits 0. Errors inside validators are suppressed.

## Validators

- validate-banned-unicode.sh detects em-dash, en-dash, curly quotes, NBSP, ellipsis. Reports codepoint and ASCII replacement.
- validate-frontmatter.sh checks SPEC docs have YAML frontmatter with required fields.
- validate-spec-status.sh checks status enum.
- validate-memory-entry-length.sh checks MEMORY entries under 150 chars.

## Bypass

Paths under output, .git, node_modules, dist, raw are skipped.

## Toggle

SAVIA_WRITE_VALIDATORS_ENABLED set to false silences the hook.

## Warning format

[WARN][validator-name][file:line] message and suggested fix.

## Latency

Target under 100ms p95. Measured 23ms on a small file.

## Adding a validator

Drop a new validate-x.sh in validators dir. Must accept FILE as arg and exit 0 always. Warnings go to stderr.
