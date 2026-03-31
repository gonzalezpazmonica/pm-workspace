#!/bin/bash
# post-tool-failure-log.sh — Structured tool failure logging (SPEC-068)
# PostToolUseFailure hook: categorizes errors, adds retry hints, detects patterns.
# Async, never blocks.
set -uo pipefail

LOG_DIR="${HOME}/.pm-workspace/tool-failures"
mkdir -p "$LOG_DIR"

# Read hook input (JSON with tool_name, tool_input, error)
INPUT=$(cat 2>/dev/null || true)
[[ -z "$INPUT" ]] && exit 0

TOOL=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
ERROR_SNIPPET=$(echo "$INPUT" | grep -o '"error":"[^"]*"' | cut -d'"' -f4 2>/dev/null | head -c 200 || echo "")
[[ -z "$ERROR_SNIPPET" ]] && ERROR_SNIPPET=$(echo "$INPUT" | head -c 300)

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOG_DIR/$DATE.jsonl"

# ── ERROR CATEGORIZATION ──
categorize_error() {
    local err="$1"
    local err_lower
    err_lower=$(echo "$err" | tr '[:upper:]' '[:lower:]')

    if echo "$err_lower" | grep -qE '(permission denied|eacces|not authorized|forbidden|403)'; then
        echo "permission|Check file permissions or run with appropriate access"
    elif echo "$err_lower" | grep -qE '(no such file|enoent|not found|does not exist|command not found)'; then
        echo "not_found|Verify file path exists and check spelling"
    elif echo "$err_lower" | grep -qE '(timed? ?out|etimedout|deadline exceeded|timeout)'; then
        echo "timeout|Retry the operation or increase timeout"
    elif echo "$err_lower" | grep -qE '(syntax error|unexpected token|parse error|invalid json|unterminated)'; then
        echo "syntax|Review input syntax — check for missing quotes or brackets"
    elif echo "$err_lower" | grep -qE '(econnrefused|econnreset|dns|certificate|network|ssl|fetch failed)'; then
        echo "network|Check connectivity and retry in a few seconds"
    else
        echo "unknown|Review error details and retry with adjusted parameters"
    fi
}

CATEGORIZED=$(categorize_error "$ERROR_SNIPPET")
CATEGORY=$(echo "$CATEGORIZED" | cut -d'|' -f1)
RETRY_HINT=$(echo "$CATEGORIZED" | cut -d'|' -f2)

# ── PATTERN DETECTION (3+ same tool failures/day) ──
PATTERN=""
if [[ -f "$LOG_FILE" ]]; then
    SAME_TOOL_COUNT=$(grep -c "\"tool\":\"$TOOL\"" "$LOG_FILE" 2>/dev/null || echo "0")
    if [[ "$SAME_TOOL_COUNT" -ge 2 ]]; then
        PATTERN=",\"pattern\":\"repeated\",\"count\":$((SAME_TOOL_COUNT + 1))"
    fi
fi

# ── WRITE STRUCTURED LOG ──
SAFE_SNIPPET=$(echo "$ERROR_SNIPPET" | tr '"' "'" | tr '\n' ' ' | head -c 200)
echo "{\"ts\":\"$TS\",\"tool\":\"$TOOL\",\"category\":\"$CATEGORY\",\"retry_hint\":\"$RETRY_HINT\",\"error\":\"$SAFE_SNIPPET\"$PATTERN}" >> "$LOG_FILE" 2>/dev/null || true

exit 0
