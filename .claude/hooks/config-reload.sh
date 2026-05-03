#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# config-reload.sh — Invalidate caches on settings change
# Event: ConfigChange | Async: true
# SPEC-071: Hook System Overhaul (Slice 4)

INPUT=$(timeout 2 cat 2>/dev/null) || true
[[ -z "$INPUT" ]] && exit 0

SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null) || exit 0
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.file_path // empty' 2>/dev/null) || true
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG_DIR="$REPO_ROOT/output/config-changes"
mkdir -p "$LOG_DIR" 2>/dev/null || true

printf '{"ts":"%s","source":"%s","file":"%s"}\n' \
  "$TIMESTAMP" "$SOURCE" "$FILE_PATH" >> "$LOG_DIR/changes.jsonl" 2>/dev/null

# Invalidate profile cache if user settings changed
if [[ "$SOURCE" == "user_settings" ]] || [[ "$SOURCE" == "local_settings" ]]; then
  SAVIA_TMP="${TMPDIR:-${HOME}/.savia/tmp}"
  rm -f "$SAVIA_TMP/savia-profile-cache" 2>/dev/null || true
fi

exit 0
