#!/usr/bin/env bash
# memory-origin-gate.sh — PostToolUse hook for SE-352: turn taint + origin gating.
# set -uo pipefail
#
# Fires after each tool call. Maintains a per-turn taint flag keyed by session_id.
# When a tool result comes from a network source (webfetch, web-research, curl,
# wget, gh api, git fetch remote), the rest of the turn is marked TAINTED so any
# memory saved afterwards is classified origin=untrusted by memory-save.sh.
#
# Taint file: /tmp/savia-memory-taint/<session_id> (0600, auto-expired 30min)
#
# Activation: SAVIA_MEMORY_ORIGIN_GATE=on (default: on — fail-safe, never blocks)
# Fail-soft:  always exits 0; never blocks the main flow.
#
# Input (stdin, JSON from PostToolUse event):
#   { "tool_name": "Bash", "tool_input": {"command": "curl ..."}, "session_id": "abc" }
#
# Ref: SE-352 — Trust-Gated Memory (provenance + taint)
set -uo pipefail

# ── Guard: fail-safe ON by default (only explicit off disables) ──────────────
SAVIA_MEMORY_ORIGIN_GATE="${SAVIA_MEMORY_ORIGIN_GATE:-on}"
if [[ "$SAVIA_MEMORY_ORIGIN_GATE" != "on" ]]; then
  exit 0
fi

# ── Taint dir ─────────────────────────────────────────────────────────────────
TAINT_DIR="/tmp/savia-memory-taint"
mkdir -p "$TAINT_DIR" 2>/dev/null || exit 0
# Clean stale taint files (> 30 min old)
find "$TAINT_DIR" -type f -mmin +30 -delete 2>/dev/null || true

# ── Read PostToolUse input (with timeout) ─────────────────────────────────────
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(timeout 2 cat 2>/dev/null) || true
fi
[[ -z "$INPUT" ]] && exit 0

# ── Validate JSON (fail-soft on bad input) ────────────────────────────────────
if ! echo "$INPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  exit 0
fi

TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_name', ''))
" 2>/dev/null) || TOOL_NAME=""
SESSION_ID=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('session_id', 'unknown'))
" 2>/dev/null) || SESSION_ID="unknown"
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {}) or {}
print(str(ti.get('command', ti.get('url', '')))[:500])
" 2>/dev/null) || COMMAND=""

# ── Network-source detection ──────────────────────────────────────────────────
# Tools that pull data from the network → taint the turn for memory purposes.
NETWORK_TOOL=false
case "$TOOL_NAME" in
  webfetch|web-fetch|WebFetch) NETWORK_TOOL=true ;;
esac
if [[ "$TOOL_NAME" == "Bash" ]] && echo "$COMMAND" | grep -qE '\b(curl|wget|git[[:space:]]+fetch|git[[:space:]]+pull|gh[[:space:]]+api|pip[[:space:]]+install|npm[[:space:]]+install|uv[[:space:]]+pip|webfetch)\b'; then
  NETWORK_TOOL=true
fi
if echo "$COMMAND" | grep -qE '^https?://'; then
  NETWORK_TOOL=true
fi

# ── Write taint file (no data, just the flag) ────────────────────────────────
if $NETWORK_TOOL && [[ -n "$SESSION_ID" && "$SESSION_ID" != "unknown" ]]; then
  TS=$(date -u +%s 2>/dev/null || echo 0)
  printf '%s\n' "$TS" > "$TAINT_DIR/$SESSION_ID" 2>/dev/null || true
fi

exit 0
