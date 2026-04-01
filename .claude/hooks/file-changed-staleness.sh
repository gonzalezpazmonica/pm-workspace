#!/usr/bin/env bash
set -uo pipefail
# file-changed-staleness.sh — Mark code maps stale on file changes
# Event: FileChanged | Async: true | Budget: <100ms
# SPEC-071: Hook System Overhaul (Slice 4)

INPUT=$(timeout 1 cat 2>/dev/null) || exit 0
FILE=$(printf '%s' "$INPUT" | jq -r '.file_path // empty' 2>/dev/null) || exit 0
[[ -z "$FILE" ]] && exit 0

REPO="${CLAUDE_PROJECT_DIR:-$(pwd)}"
touch "$REPO/.claude/.maps-stale" 2>/dev/null || true
exit 0
