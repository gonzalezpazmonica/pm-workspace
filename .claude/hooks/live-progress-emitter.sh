#!/usr/bin/env bash
# live-progress-emitter.sh — SPEC-042: PostToolUse hook that emits progress lines to stderr
# Format: [SAVIA-PROGRESS] {agent}: {action} [{elapsed}ms]
# Master switch: SAVIA_LIVE_PROGRESS=on (default off)
# Event: PostToolUse | Async: true | Tier: observability (never blocks)

set -uo pipefail

ERR_LOG="$HOME/.savia/hook-errors.log"
trap 'echo "[$(date +%H:%M:%S)] live-progress-emitter: $BASH_COMMAND failed (line $LINENO)" >> "$ERR_LOG" 2>/dev/null' ERR

# Master switch — default off
SAVIA_LIVE_PROGRESS="${SAVIA_LIVE_PROGRESS:-off}"
[[ "$SAVIA_LIVE_PROGRESS" == "on" ]] || exit 0

# Read tool info from stdin (JSON)
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
DURATION_MS=$(echo "$INPUT" | jq -r '.duration_ms // empty' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null)

[[ -z "$TOOL_NAME" ]] && exit 0

# Compute elapsed: use duration_ms from hook payload if present, else wall clock
# Start time is stored by PreToolUse sibling (live-progress-hook.sh) in tmp file
START_FILE="$HOME/.savia/.progress-start-${TOOL_NAME}-$$"
if [[ -n "$DURATION_MS" && "$DURATION_MS" =~ ^[0-9]+$ ]]; then
    ELAPSED="${DURATION_MS}"
elif [[ -f "$START_FILE" ]]; then
    START_TS=$(cat "$START_FILE" 2>/dev/null || echo "0")
    NOW_MS=$(date +%s%3N 2>/dev/null || echo "0")
    ELAPSED=$(( NOW_MS - START_TS ))
    rm -f "$START_FILE"
else
    ELAPSED=0
fi

# Determine agent label from env (SAVIA_AGENT_NAME) or fallback to tool name
AGENT="${SAVIA_AGENT_NAME:-savia}"

# Build action description per tool type
case "$TOOL_NAME" in
    Bash)
        DESC=$(echo "$TOOL_INPUT" | jq -r '.description // .command // ""' 2>/dev/null | head -c 60)
        ACTION="bash: ${DESC}"
        ;;
    Edit)
        FILE=$(echo "$TOOL_INPUT" | jq -r '.filePath // .file_path // ""' 2>/dev/null | sed 's|.*/||')
        ACTION="edit: ${FILE}"
        ;;
    Write)
        FILE=$(echo "$TOOL_INPUT" | jq -r '.filePath // .file_path // ""' 2>/dev/null | sed 's|.*/||')
        ACTION="write: ${FILE}"
        ;;
    Read)
        FILE=$(echo "$TOOL_INPUT" | jq -r '.filePath // .file_path // ""' 2>/dev/null | sed 's|.*/||')
        ACTION="read: ${FILE}"
        ;;
    Agent|Task*)
        DESC=$(echo "$TOOL_INPUT" | jq -r '.description // .prompt // ""' 2>/dev/null | head -c 50)
        ACTION="agent: ${DESC}"
        ;;
    Glob)
        PAT=$(echo "$TOOL_INPUT" | jq -r '.pattern // ""' 2>/dev/null | head -c 40)
        ACTION="glob: ${PAT}"
        ;;
    Grep)
        PAT=$(echo "$TOOL_INPUT" | jq -r '.pattern // ""' 2>/dev/null | head -c 40)
        ACTION="grep: ${PAT}"
        ;;
    Skill)
        SKILL=$(echo "$TOOL_INPUT" | jq -r '.name // .skill // ""' 2>/dev/null)
        ACTION="skill: ${SKILL}"
        ;;
    *)
        ACTION="${TOOL_NAME,,}"
        ;;
esac

# Emit progress line to stderr in canonical format
echo "[SAVIA-PROGRESS] ${AGENT}: ${ACTION} [${ELAPSED}ms]" >&2

exit 0
