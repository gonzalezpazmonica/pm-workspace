#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
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

# ── Compress via standalone script (all filters moved to output-compress.sh) ─────────────────────────────────────────
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
COMPRESS_SCRIPT="$PROJECT_DIR/scripts/output-compress.sh"

if [[ -x "$COMPRESS_SCRIPT" ]]; then
    COMPRESSED=$(printf '%s\n' "$OUTPUT" | bash "$COMPRESS_SCRIPT" --command "$COMMAND" 2>/dev/null) || COMPRESSED=""
else
    COMPRESSED=""
fi
[[ -z "$COMPRESSED" ]] && exit 0

# ── Calculate metrics and log ─────────────────────────────────────────────
ORIGINAL_TOKENS=$((${#OUTPUT} / 4))
COMPRESSED_TOKENS=$((${#COMPRESSED} / 4))
TOKENS_SAVED=$((ORIGINAL_TOKENS - COMPRESSED_TOKENS))

if [[ $ORIGINAL_TOKENS -gt 0 ]]; then
    RATIO=$(( (TOKENS_SAVED * 100) / ORIGINAL_TOKENS ))
    if [[ $RATIO -gt 20 ]]; then
        TRACKER="$PROJECT_DIR/scripts/context-tracker.sh"
        if [[ -x "$TRACKER" ]]; then
            bash "$TRACKER" log "bash-compress" "$COMMAND_BASE" "$TOKENS_SAVED" 2>/dev/null || true
        fi
    fi
fi

# Emit compressed output to stdout (injected as additionalContext by Claude Code)
echo "$COMPRESSED"
exit 0
