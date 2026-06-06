#!/bin/bash
# auto-zoom-out.sh — SE-091 Slice 2: inject zoom-out context on architecture edits
# Ref: SPEC-SE-091-CAVEMAN-ALWAYS, docs/rules/domain/caveman-default.md
set -uo pipefail

TOOL_NAME="${OPENCODE_TOOL_NAME:-}"
FILE_PATH="${OPENCODE_TOOL_INPUT_PATH:-${OPENCODE_TOOL_INPUT_FILE_PATH:-}}"

[[ "$TOOL_NAME" =~ ^(Edit|Write)$ ]] || exit 0
[[ "$FILE_PATH" =~ (docs/architecture|docs/propuestas|\.arch\.md|ROADMAP\.md|SPEC-.*\.md) ]] || exit 0

echo "[auto-zoom-out] Zoom out: what dependencies does this affect? Second-order effects? What would break?" >&2
exit 0  # WARN only — never block
