#!/bin/bash
# post-tool-failure-log.sh — Log tool execution failures for debugging
# PostToolUseFailure hook: captures tool name, input, and error details.
# Async, never blocks. Inspired by disler/claude-code-hooks-mastery.
set -uo pipefail

LOG_DIR="${HOME}/.pm-workspace/tool-failures"
mkdir -p "$LOG_DIR"

# Read hook input (JSON with tool_name, tool_input, error)
INPUT=$(cat 2>/dev/null || true)
[[ -z "$INPUT" ]] && exit 0

TOOL=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE=$(date +%Y-%m-%d)

# Append to daily log (JSONL)
echo "{\"ts\":\"$TS\",\"tool\":\"$TOOL\",\"input\":$(echo "$INPUT" | head -c 500)}" >> "$LOG_DIR/$DATE.jsonl" 2>/dev/null || true

exit 0
