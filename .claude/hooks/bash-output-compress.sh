#!/bin/bash
set -uo pipefail
# ────────────────────────────────────────────────────────────────────────────
# PostToolUse Hook: bash-output-compress.sh
# Compresses verbose Bash output to reduce context token consumption.
# Inspired by rtk-ai/rtk (60-90% token reduction on dev commands).
# Async hook — NEVER blocks. Always exits 0.
# ────────────────────────────────────────────────────────────────────────────

# Only trigger for Bash tool
if [[ "${TOOL_NAME:-}" != "Bash" ]]; then
    exit 0
fi

OUTPUT="${TOOL_OUTPUT:-}"
[[ -z "$OUTPUT" ]] && exit 0

# Count lines
LINE_COUNT=$(printf '%s\n' "$OUTPUT" | wc -l)

# Pass through short output (<=30 lines)
if [[ $LINE_COUNT -le 30 ]]; then
    exit 0
fi

# Extract command from TOOL_INPUT JSON
COMMAND=$(printf '%s' "${TOOL_INPUT:-}" | grep -o '"command":\s*"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "unknown")
COMMAND_BASE=$(printf '%s' "$COMMAND" | awk '{print $1}' 2>/dev/null || echo "unknown")

# ── Generic compression pipeline ──────────────────────────────────────────
compress_generic() {
    local input="$1"
    printf '%s\n' "$input" \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | sed '/^[[:space:]]*$/d' \
        | awk '
            prev == $0 { count++; next }
            count > 0 { print prev " [...repeated " count+1 " times]"; count=0 }
            { if (prev != "") print prev; prev = $0 }
            END { if (count > 0) print prev " [...repeated " count+1 " times]"; else if (prev != "") print prev }
        ' \
        | head -50
}

# ── Specialized filters ───────────────────────────────────────────────────
compress_git_log() {
    printf '%s\n' "$1" \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | grep -E '^(commit |[a-f0-9]{7,}|    )' \
        | head -50
}

compress_git_diff() {
    printf '%s\n' "$1" \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | grep -E '^(diff |index |\+\+\+|---|@@|\+|-|Binary)' \
        | head -50
}

compress_test_output() {
    printf '%s\n' "$1" \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | grep -iE '(passed|failed|error|FAIL|OK|Total|summary|test result|Tests run)' \
        | head -50
}

compress_npm() {
    printf '%s\n' "$1" \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | grep -ivE '(^\s*$|npm warn|added [0-9]+ packages|up to date|audited|progress)' \
        | head -50
}

# ── Apply compression based on command type ───────────────────────────────
COMPRESSED=""
case "$COMMAND" in
    *"git log"*)   COMPRESSED=$(compress_git_log "$OUTPUT") ;;
    *"git diff"*)  COMPRESSED=$(compress_git_diff "$OUTPUT") ;;
    *"dotnet test"*|*"pytest"*|*"vitest"*|*"cargo test"*)
                   COMPRESSED=$(compress_test_output "$OUTPUT") ;;
    *"npm "*|*"pnpm "*)
                   COMPRESSED=$(compress_npm "$OUTPUT") ;;
    *)             COMPRESSED=$(compress_generic "$OUTPUT") ;;
esac

# ── Calculate metrics ─────────────────────────────────────────────────────
ORIGINAL_TOKENS=$((${#OUTPUT} / 4))
COMPRESSED_TOKENS=$((${#COMPRESSED} / 4))
TOKENS_SAVED=$((ORIGINAL_TOKENS - COMPRESSED_TOKENS))

# Only log if meaningful compression achieved (>20%)
if [[ $ORIGINAL_TOKENS -gt 0 ]]; then
    RATIO=$(( (TOKENS_SAVED * 100) / ORIGINAL_TOKENS ))
    if [[ $RATIO -gt 20 ]]; then
        PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
        TRACKER="$PROJECT_DIR/scripts/context-tracker.sh"
        if [[ -x "$TRACKER" ]]; then
            bash "$TRACKER" log "bash-compress" "$COMMAND_BASE" "$TOKENS_SAVED" 2>/dev/null || true
        fi
    fi
fi

# Async hook — output goes to Claude's context as replacement
# Note: Claude Code PostToolUse hooks cannot modify TOOL_OUTPUT directly.
# This hook logs metrics only. Future: stdout replacement when supported.
exit 0
