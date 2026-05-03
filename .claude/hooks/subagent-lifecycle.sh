#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# subagent-lifecycle.sh — Track agent spawns and completions
# Events: SubagentStart, SubagentStop | Async: true
# SPEC-071: Hook System Overhaul (Slice 4)

INPUT=$(timeout 3 cat 2>/dev/null) || true
[[ -z "$INPUT" ]] && exit 0

EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null) || exit 0
AGENT_TYPE=$(printf '%s' "$INPUT" | jq -r '.agent_type // "unknown"' 2>/dev/null) || exit 0
AGENT_ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // "unknown"' 2>/dev/null) || exit 0
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG_DIR="$REPO_ROOT/output/agent-lifecycle"
mkdir -p "$LOG_DIR" 2>/dev/null || true
LOG="$LOG_DIR/lifecycle.jsonl"

if [[ "$EVENT" == "SubagentStop" ]]; then
  TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.agent_transcript_path // empty' 2>/dev/null) || true
  printf '{"ts":"%s","event":"stop","agent":"%s","id":"%s","transcript":"%s"}\n' \
    "$TIMESTAMP" "$AGENT_TYPE" "$AGENT_ID" "$TRANSCRIPT" >> "$LOG" 2>/dev/null
else
  printf '{"ts":"%s","event":"start","agent":"%s","id":"%s"}\n' \
    "$TIMESTAMP" "$AGENT_TYPE" "$AGENT_ID" >> "$LOG" 2>/dev/null
fi
exit 0
