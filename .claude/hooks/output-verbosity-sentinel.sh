#!/usr/bin/env bash
set -uo pipefail
# output-verbosity-sentinel.sh — SE-224 Slice 1
#
# PostToolUse hook. Classifies the current turn and emits a verbosity level
# recommendation (L1 or L2) as hookSpecificOutput on stderr.
#
# The sentinel is ANNOTATION-ONLY — never blocks, never modifies content.
# Always exits 0.
#
# Verbosity levels:
#   L1 — no ceremony: no preamble, no postamble (already in caveman-default.md)
#   L2 — L1 + no echo of context already in window (DEFAULT for clean tool_result)
#
# Turn classification (structural, zero LLM):
#   tool_result with no is_error           → MECHANICAL → L2
#   tool_result with is_error == true      → ERROR      → L1 (full reasoning needed)
#   user message (non-tool input)          → NEW_ASK    → L1
#   unknown / missing input                → L1         (safe default)
#
# Sentinel tag for idempotency (appended to tail of system prompt by caller):
#   <!-- VERBOSITY_LEVEL:L2 -->
#
# Why tail (not head): preserves the prefix cache anchored at the start of the
# system prompt. Prepending would bust the cache on every turn. Appending is
# invisible to the cached prefix. Ref: SE-224.
#
# Ref: docs/propuestas/SE-224-headroom-effort-routing-verbosity.md
#      docs/rules/domain/caveman-default.md

SAVIA_ENV="$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
if [[ -f "$SAVIA_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$SAVIA_ENV" 2>/dev/null || true
fi

# ── Read stdin (hook protocol — consume even if unused) ──────────────────────
INPUT="$(cat /dev/stdin 2>/dev/null || true)"

# ── Classify turn ────────────────────────────────────────────────────────────
TOOL_TYPE="${TOOL_NAME:-}"
IS_ERROR="${TOOL_ERROR:-}"

classify_turn() {
  # Priority 1: error in tool result → full reasoning needed
  if [[ "${IS_ERROR:-}" == "true" || "${IS_ERROR:-}" == "1" ]]; then
    echo "ERROR"
    return
  fi

  # Priority 2: if TOOL_NAME is set, this is a tool_result turn
  if [[ -n "$TOOL_TYPE" ]]; then
    echo "MECHANICAL"
    return
  fi

  # Priority 3: user message (no tool involved)
  echo "NEW_ASK"
}

TURN_CLASS="$(classify_turn)"

# ── Map class → verbosity level ──────────────────────────────────────────────
case "$TURN_CLASS" in
  MECHANICAL)
    LEVEL="L2"
    ;;
  ERROR|NEW_ASK|*)
    LEVEL="L1"
    ;;
esac

# ── Emit sentinel as hookSpecificOutput (JSON on stderr) ─────────────────────
# OpenCode/Claude Code reads hookSpecificOutput from stderr when it's valid JSON.
SENTINEL_TAG="<!-- VERBOSITY_LEVEL:${LEVEL} -->"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo 'unknown')"

printf '%s\n' "{\"hookSpecificOutput\":\"${SENTINEL_TAG}\",\"verbosityLevel\":\"${LEVEL}\",\"turnClass\":\"${TURN_CLASS}\",\"ts\":\"${TS}\",\"hook\":\"output-verbosity-sentinel\",\"spec\":\"SE-224\"}" >&2

# ── Always exit 0 — annotation only, never blocks ───────────────────────────
exit 0
