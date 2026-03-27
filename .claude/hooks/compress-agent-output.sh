#!/usr/bin/env bash
# compress-agent-output.sh — Streaming compression of agent outputs (SPEC-041 P4)
# PostToolUse hook for Task — compresses outputs >200 tokens in active dev sessions
# async: true — never blocks main flow
set -euo pipefail

# Only activate in multi-agent sessions (dev-session active or SDD_COMPRESS_AGENT_OUTPUT)
SESSION_STATE_DIR="output/dev-sessions"
DEV_SESSION_ACTIVE=false

# Check if there's an active dev-session with an implementing slice
if ls "$SESSION_STATE_DIR"/*/state.json 2>/dev/null | \
    xargs grep -l '"status": "implementing"' 2>/dev/null | grep -q .; then
    DEV_SESSION_ACTIVE=true
fi

# Allow env var override
if [[ "${SDD_COMPRESS_AGENT_OUTPUT:-false}" == "true" ]]; then
    DEV_SESSION_ACTIVE=true
fi

if [[ "$DEV_SESSION_ACTIVE" != "true" ]]; then
    exit 0
fi

# Read agent output from stdin
TOOL_OUTPUT=$(cat /dev/stdin 2>/dev/null || echo "")

if [[ -z "$TOOL_OUTPUT" ]]; then
    exit 0
fi

# Estimate tokens (rough: chars / 4)
CHAR_COUNT=${#TOOL_OUTPUT}
TOKEN_ESTIMATE=$((CHAR_COUNT / 4))

# Only compress if output > 200 tokens
if [[ $TOKEN_ESTIMATE -le 200 ]]; then
    exit 0
fi

# Save raw output to disk before compression
TS=$(date +%Y%m%dT%H%M%S)
RAW_DIR="output/dev-sessions/compressed-raw"
mkdir -p "$RAW_DIR"
RAW_FILE="$RAW_DIR/${TS}.txt"
echo "$TOOL_OUTPUT" > "$RAW_FILE"

# Generate compressed bullets via Claude haiku (speed over quality)
BULLETS=$(echo "$TOOL_OUTPUT" | \
    claude -p "Compress this agent output to 5-8 structured bullet points. Include: action taken, files modified, key decisions/errors, state for next agent. Be concrete. Output ONLY the bullets, no preamble." \
    --model claude-haiku-4-5-20251001 2>/dev/null || \
    echo "- Output compressed (raw saved to $RAW_FILE)")

WORD_COUNT=$(echo "$BULLETS" | wc -w)
echo "<!-- COMPRESSED (${TOKEN_ESTIMATE} tokens → ${WORD_COUNT} words | raw: $RAW_FILE) -->"
echo "$BULLETS"
