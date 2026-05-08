#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# file-changed-staleness.sh — Mark code maps stale on file changes
# Event: FileChanged | Async: true | Budget: <100ms
# SPEC-071: Hook System Overhaul (Slice 4)

ERR_LOG="$HOME/.savia/hook-errors.log"
trap 'echo "[$(date +%H:%M:%S)] file-changed-staleness: $BASH_COMMAND failed (line $LINENO)" >> "$ERR_LOG" 2>/dev/null' ERR

INPUT=$(timeout 1 cat 2>/dev/null) || exit 0
FILE=$(printf '%s' "$INPUT" | jq -r '.file_path // empty' 2>/dev/null) || exit 0
[[ -z "$FILE" ]] && exit 0

REPO="${CLAUDE_PROJECT_DIR:-$(pwd)}"
mkdir -p "$REPO/.claude" 2>/dev/null
touch "$REPO/.claude/.maps-stale" || echo "[$(date +%H:%M:%S)] file-changed-staleness: touch failed for $REPO/.claude/.maps-stale" >> "$ERR_LOG" 2>/dev/null
exit 0
