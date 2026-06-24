#!/usr/bin/env bash
# SE-224 Slice 1 — verbosity sentinel
# PostToolUse hook. Classifies the current turn and emits verbosity level hint.
#
# Principle: inject at END of system prompt, not beginning (preserves prefix cache).
#
# Classification (structural, zero LLM):
#   MECHANICAL: last tool result is success + short output (< 100 chars)
#   ERROR:      last tool result has is_error=true or contains "ERROR:"|"FAIL:"|"FATAL"
#   NEW_ASK:    substantial output / unknown — default safe value
#
# Output: emits classification tag to stderr as hookSpecificOutput JSON.
# Telemetry: output/verbosity-telemetry.jsonl — {ts, classification, output_len}
#
# Master switch: SAVIA_VERBOSITY_SENTINEL=on|off  (default: on)
# Does NOT modify any files. Pure observability hook. Exit 0 always.

set -uo pipefail

# ── Master switch ─────────────────────────────────────────────────────────────
if [[ "${SAVIA_VERBOSITY_SENTINEL:-on}" == "off" ]]; then
    exit 0
fi

# ── Resolve workspace ─────────────────────────────────────────────────────────
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_WORKSPACE="${CLAUDE_PROJECT_DIR:-$(cd "$_HOOK_DIR/../.." && pwd)}"

# ── Read stdin (PostToolUse JSON payload) ─────────────────────────────────────
INPUT=""
if [[ ! -t 0 ]]; then
    INPUT=$(cat)
fi

# ── Extract fields from JSON (jq or pure bash fallback) ─────────────────────
_extract_field() {
    local field="$1"
    local json="$2"
    if command -v jq &>/dev/null; then
        printf '%s' "$json" | jq -r ".$field // empty" 2>/dev/null || true
    else
        # Pure bash regex fallback — best-effort for is_error boolean and output string
        local val
        val=$(printf '%s' "$json" | grep -o "\"${field}\":[^,}]*" | head -1 | sed 's/.*://' | tr -d '"' | tr -d ' ') 2>/dev/null || true
        printf '%s' "$val"
    fi
}

# ── Determine classification ──────────────────────────────────────────────────
CLASSIFICATION="NEW_ASK"  # safe default
VERBOSITY="L1"             # caveman-default level

# Read tool result fields
IS_ERROR=""
OUTPUT_CONTENT=""

if [[ -n "$INPUT" ]]; then
    if command -v jq &>/dev/null; then
        IS_ERROR=$(printf '%s' "$INPUT"    | jq -r '.tool_result.is_error // .is_error // false' 2>/dev/null || echo "false")
        OUTPUT_CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_result.output // .output // ""' 2>/dev/null || true)
        # Also check TOOL_OUTPUT env (set by OpenCode before calling hook)
        if [[ -z "$OUTPUT_CONTENT" ]]; then
            OUTPUT_CONTENT="${TOOL_OUTPUT:-}"
        fi
    else
        IS_ERROR="${TOOL_RESULT_IS_ERROR:-false}"
        OUTPUT_CONTENT="${TOOL_OUTPUT:-}"
    fi
else
    IS_ERROR="${TOOL_RESULT_IS_ERROR:-false}"
    OUTPUT_CONTENT="${TOOL_OUTPUT:-}"
fi

OUTPUT_LEN="${#OUTPUT_CONTENT}"

# Classification logic
if [[ "$IS_ERROR" == "true" ]] || printf '%s' "$OUTPUT_CONTENT" | grep -qE '(^|\s)(ERROR:|FAIL:|FATAL)'; then
    CLASSIFICATION="ERROR"
    VERBOSITY="L1"  # full reasoning — do not reduce
elif [[ $OUTPUT_LEN -lt 100 ]]; then
    CLASSIFICATION="MECHANICAL"
    VERBOSITY="L2"  # concise: no echo of context already in window
else
    CLASSIFICATION="NEW_ASK"
    VERBOSITY="L1"  # default: full reasoning
fi

# ── Emit to stderr (hookSpecificOutput for observability) ────────────────────
# Only emit verbosity hint for MECHANICAL turns.
# ERROR and NEW_ASK: full reasoning — no hint injected.
if [[ "$CLASSIFICATION" == "MECHANICAL" ]]; then
    printf '[SE-224] turn=%s verbosity=%s\n' "$CLASSIFICATION" "$VERBOSITY" >&2
    printf '<!-- VERBOSITY_LEVEL:%s -->\n' "$VERBOSITY" >&2
fi

# ── Telemetry ─────────────────────────────────────────────────────────────────
TELEMETRY_DIR="${_WORKSPACE}/output"
if [[ -d "$TELEMETRY_DIR" ]]; then
    TELEMETRY_FILE="${TELEMETRY_DIR}/verbosity-telemetry.jsonl"
    TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")
    TOOL_NAME_LOG="${TOOL_NAME:-unknown}"
    printf '{"ts":"%s","hook":"verbosity-sentinel","classification":"%s","verbosity":"%s","output_len":%d,"tool":"%s"}\n' \
        "$TS" "$CLASSIFICATION" "$VERBOSITY" "$OUTPUT_LEN" "$TOOL_NAME_LOG" \
        >> "$TELEMETRY_FILE" 2>/dev/null || true
fi

exit 0
