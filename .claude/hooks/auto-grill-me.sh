#!/bin/bash
# auto-grill-me.sh — SE-091 Slice 2: inject grill-me context on code edits
# Ref: SPEC-SE-091-CAVEMAN-ALWAYS, docs/rules/domain/caveman-default.md
set -uo pipefail

TOOL_NAME="${OPENCODE_TOOL_NAME:-}"
FILE_PATH="${OPENCODE_TOOL_INPUT_PATH:-${OPENCODE_TOOL_INPUT_FILE_PATH:-}}"

# Only trigger on Edit/Write to code files
[[ "$TOOL_NAME" =~ ^(Edit|Write)$ ]] || exit 0
[[ "$FILE_PATH" =~ \.(py|sh|ts|js|cs|go|rs|java|rb|php)$ ]] || exit 0

echo "[auto-grill-me] Hunt weaknesses: edge cases, unstated assumptions, error paths, untested branches." >&2
exit 0  # WARN only — never block
