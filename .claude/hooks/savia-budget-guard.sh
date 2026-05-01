#!/usr/bin/env bash
set -uo pipefail
# savia-budget-guard.sh — SPEC-127 Slice 5
#
# PreToolUse advisory hook (warns, NEVER blocks). Reads the active threshold
# from `scripts/savia-quota-tracker.sh threshold` and emits a one-line nudge
# to stderr at 70%, 85%, 95% of the user's monthly budget. Idempotent per
# session (one nudge per threshold per session — set marker in /tmp).
#
# When the user's preferences declare `budget_kind: none` (e.g. LocalAI /
# Ollama / self-hosted, no quota), the threshold returns "none" and this
# hook silently exits 0.
#
# This hook is wired in `.claude/settings.json` under PreToolUse. It reads
# the tool input JSON from stdin but only consumes it to avoid blocking the
# parent shell — the hook does NOT inspect tool name or arguments. It is a
# generic per-call counter wrapper that never blocks.
#
# Reference: SPEC-127 Slice 5 AC-5.2
# Reference: scripts/savia-quota-tracker.sh

# Drain stdin (Claude Code hooks send JSON; we don't parse it here).
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(timeout 2 cat 2>/dev/null) || true
fi
: "${INPUT:=}"

ROOT="${CLAUDE_PROJECT_DIR:-${SAVIA_WORKSPACE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
TRACKER="${ROOT}/scripts/savia-quota-tracker.sh"

# Bail silently if the tracker is missing (e.g. partial install)
if [[ ! -x "$TRACKER" ]]; then
  exit 0
fi

# Record the event (1 request unit) — tracker handles "none" budget by
# silent skip, so this is safe regardless of user policy.
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EVENT=$(printf '{"ts":"%s","kind":"req","value":1,"tool":"PreToolUse"}' "$TS")
bash "$TRACKER" record "$EVENT" 2>/dev/null || true

# Read current threshold marker
THR=$(bash "$TRACKER" threshold 2>/dev/null)
case "$THR" in
  none|under-70|"")
    exit 0
    ;;
esac

# Emit a once-per-session nudge per threshold. Use a /tmp marker keyed by
# the bash session PID + threshold so we don't nag every PreToolUse call.
MARKER_DIR="${TMPDIR:-/tmp}/savia-budget-${USER:-default}"
mkdir -p "$MARKER_DIR" 2>/dev/null || true
MARKER="$MARKER_DIR/$$.$THR"

if [[ ! -f "$MARKER" ]]; then
  : > "$MARKER" 2>/dev/null || true
  case "$THR" in
    over-70)   echo "Savia budget: 70% of monthly quota consumed. Consider rebalancing or pausing intensive operations." >&2 ;;
    over-85)   echo "Savia budget: 85% of monthly quota consumed. Reserve remaining capacity for critical work." >&2 ;;
    over-95)   echo "Savia budget: 95% of monthly quota consumed. Only essential operations recommended for the rest of the period." >&2 ;;
    exceeded)  echo "Savia budget: monthly quota EXCEEDED. Operations continue but may incur overage from your provider." >&2 ;;
  esac
fi

# NEVER block — always exit 0
exit 0
