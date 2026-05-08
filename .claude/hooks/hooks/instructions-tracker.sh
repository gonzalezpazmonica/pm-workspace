#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# instructions-tracker.sh — Log which instructions/rules load per session
# Event: InstructionsLoaded | Async: true
# SPEC-071: Hook System Overhaul (Slice 4)

INPUT=$(timeout 2 cat 2>/dev/null) || true
[[ -z "$INPUT" ]] && exit 0

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.file_path // empty' 2>/dev/null) || exit 0
MEMORY_TYPE=$(printf '%s' "$INPUT" | jq -r '.memory_type // empty' 2>/dev/null) || true
LOAD_REASON=$(printf '%s' "$INPUT" | jq -r '.load_reason // empty' 2>/dev/null) || true
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG_DIR="$REPO_ROOT/output/instructions-loaded"
mkdir -p "$LOG_DIR" 2>/dev/null || true
LOG="$LOG_DIR/loaded.jsonl"

printf '{"ts":"%s","file":"%s","type":"%s","reason":"%s"}\n' \
  "$TIMESTAMP" "$FILE_PATH" "$MEMORY_TYPE" "$LOAD_REASON" >> "$LOG" 2>/dev/null
exit 0
