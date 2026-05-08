#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# task-lifecycle.sh — Log task creation and completion
# Events: TaskCreated, TaskCompleted | Async: true
# SPEC-071: Hook System Overhaul (Slice 4)

INPUT=$(timeout 3 cat 2>/dev/null) || true
[[ -z "$INPUT" ]] && exit 0

EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null) || exit 0
TASK_ID=$(printf '%s' "$INPUT" | jq -r '.task_id // empty' 2>/dev/null) || exit 0
TASK_SUBJECT=$(printf '%s' "$INPUT" | jq -r '.task_subject // empty' 2>/dev/null) || exit 0
TEAM=$(printf '%s' "$INPUT" | jq -r '.team_name // empty' 2>/dev/null) || true
TEAMMATE=$(printf '%s' "$INPUT" | jq -r '.teammate_name // empty' 2>/dev/null) || true
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG_DIR="$REPO_ROOT/output/task-lifecycle"
mkdir -p "$LOG_DIR" 2>/dev/null || true
LOG="$LOG_DIR/lifecycle.jsonl"

ACTION="created"
[[ "$EVENT" == "TaskCompleted" ]] && ACTION="completed"

printf '{"ts":"%s","action":"%s","id":"%s","subject":"%s","team":"%s","teammate":"%s"}\n' \
  "$TIMESTAMP" "$ACTION" "$TASK_ID" "$TASK_SUBJECT" "$TEAM" "$TEAMMATE" >> "$LOG" 2>/dev/null
exit 0
