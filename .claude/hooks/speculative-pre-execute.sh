#!/usr/bin/env bash
# speculative-pre-execute.sh — PostToolUse hook for SE-220 Speculative Execution (Slice 2).
set -uo pipefail
#
# Fires after each tool call. Reads the tool output + turn context and
# launches speculative pre-execution of the NEXT predicted tool in background,
# so results are ready when the LLM processes the current tool response.
#
# Activation: SAVIA_SPECULATIVE_EXECUTION=on  (default: off — opt-in per SPEC-186)
# Fail-soft:  always exits 0; never blocks the main flow.
#
# Input (stdin, JSON from OpenCode PostToolUse event):
#   {
#     "tool_name": "Read",
#     "tool_input": {...},
#     "tool_response": {...},
#     "session_id": "abc123"
#   }
#
# Ref: SE-220 — Speculative Tool Execution, Slice 2

set -uo pipefail

# ── Guard: opt-in only ────────────────────────────────────────────────────────
SAVIA_SPECULATIVE_EXECUTION="${SAVIA_SPECULATIVE_EXECUTION:-off}"
if [[ "$SAVIA_SPECULATIVE_EXECUTION" != "on" ]]; then
  exit 0
fi

# ── Resolve paths ─────────────────────────────────────────────────────────────
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$HOOK_DIR/../.." && pwd)}"
ORCHESTRATOR="$ROOT_DIR/scripts/speculative-tool-execution.py"
PYTHON="${PYTHON:-python3}"

# ── Safety: script must exist ─────────────────────────────────────────────────
if [[ ! -f "$ORCHESTRATOR" ]]; then
  exit 0
fi

# ── Read PostToolUse input (with timeout) ──────────────────────────────────────
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(timeout 2 cat 2>/dev/null) || true
fi

[[ -z "$INPUT" ]] && exit 0

# ── Validate JSON (fail-soft on bad input) ────────────────────────────────────
if ! echo "$INPUT" | "$PYTHON" -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  exit 0
fi

# ── Extract session context ───────────────────────────────────────────────────
SESSION_ID=$(echo "$INPUT" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('session_id', 'unknown'))
" 2>/dev/null) || SESSION_ID="unknown"

TOOL_NAME=$(echo "$INPUT" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_name', ''))
" 2>/dev/null) || TOOL_NAME=""

# ── Build intent hint from tool context ───────────────────────────────────────
# We reconstruct a minimal intent from the tool name and input to help the
# predictor guess the next tool. The intent is intentionally vague here;
# in production the full turn transcript would be passed.
INTENT_HINT="continue after ${TOOL_NAME} — read or search next"

ORCHESTRATOR_INPUT=$(
  "$PYTHON" -c "
import json, sys
print(json.dumps({
    'intent': sys.argv[1],
    'available_tools': ['Read', 'Grep', 'Glob', 'Bash'],
    'session_id': sys.argv[2],
}))" "$INTENT_HINT" "$SESSION_ID" 2>/dev/null
) || exit 0

# ── Launch orchestrator in background (non-blocking) ─────────────────────────
echo "$ORCHESTRATOR_INPUT" | "$PYTHON" "$ORCHESTRATOR" \
  >/dev/null 2>/dev/null &

exit 0
