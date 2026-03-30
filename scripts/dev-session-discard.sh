#!/usr/bin/env bash
set -uo pipefail
# dev-session-discard.sh — Discard a dev-session cleanly
# Usage: dev-session-discard.sh <session-id> [reason]
# SPEC-048 Phase 1

BASE_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SESSIONS_DIR="$BASE_DIR/.claude/sessions"
DEV_SESSIONS_DIR="$BASE_DIR/output/dev-sessions"
DISCARD_LOG="$DEV_SESSIONS_DIR/discard-log.jsonl"

SESSION_ID="${1:-}"
REASON="${2:-manual discard}"

if [[ "$SESSION_ID" == "--help" || "$SESSION_ID" == "-h" ]]; then
  echo "Usage: dev-session-discard.sh <session-id> [reason]"
  echo "Discard a dev-session cleanly: remove lock, archive state, log the discard."
  exit 0
fi

# ── Validate arguments ────────────────────────────────────────────────────────
if [[ -z "$SESSION_ID" ]]; then
  echo "ERROR: session ID required"
  echo "Usage: dev-session-discard.sh <session-id> [reason]"
  exit 1
fi

# ── Check session existence (lock file or state directory) ────────────────────
LOCK_FILE="$SESSIONS_DIR/${SESSION_ID}.lock"
STATE_DIR="$DEV_SESSIONS_DIR/$SESSION_ID"
STATE_FILE="$STATE_DIR/state.json"

HAS_LOCK=false
HAS_STATE=false

if [[ -f "$LOCK_FILE" ]]; then
  HAS_LOCK=true
fi
if [[ -f "$STATE_FILE" ]]; then
  HAS_STATE=true
fi

if [[ "$HAS_LOCK" == "false" && "$HAS_STATE" == "false" ]]; then
  echo "ERROR: session '$SESSION_ID' not found"
  echo "  Checked: $LOCK_FILE"
  echo "  Checked: $STATE_FILE"
  exit 1
fi

# ── Extract slice info from state file if available ───────────────────────────
SLICES_COMPLETED=0
SLICES_TOTAL=0

if [[ "$HAS_STATE" == "true" ]] && command -v python3 &>/dev/null; then
  SLICES_COMPLETED=$(python3 -c "
import json, sys
try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    print(sum(1 for s in d.get('slices', []) if s.get('status') in ('completed', 'verified')))
except (json.JSONDecodeError, FileNotFoundError, KeyError):
    print(0)
" 2>/dev/null || echo "0")
  SLICES_TOTAL=$(python3 -c "
import json, sys
try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    print(d.get('total_slices', len(d.get('slices', []))))
except (json.JSONDecodeError, FileNotFoundError, KeyError):
    print(0)
" 2>/dev/null || echo "0")
fi

# ── Ensure output directories exist ──────────────────────────────────────────
mkdir -p "$DEV_SESSIONS_DIR"

# ── Write discard log entry ──────────────────────────────────────────────────
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

_DS_SID="$SESSION_ID" _DS_REASON="$REASON" _DS_TS="$TIMESTAMP" \
  _DS_LOCK="$HAS_LOCK" _DS_STATE="$HAS_STATE" \
  _DS_DONE="$SLICES_COMPLETED" _DS_TOTAL="$SLICES_TOTAL" \
  python3 -c "
import json, os
entry = {
    'session_id': os.environ['_DS_SID'],
    'reason': os.environ['_DS_REASON'],
    'timestamp': os.environ['_DS_TS'],
    'had_lock': os.environ['_DS_LOCK'] == 'true',
    'had_state': os.environ['_DS_STATE'] == 'true',
    'slices_completed': int(os.environ['_DS_DONE']),
    'slices_total': int(os.environ['_DS_TOTAL'])
}
print(json.dumps(entry))
" >> "$DISCARD_LOG" 2>/dev/null

if [[ $? -ne 0 ]]; then
  # Fallback: write JSON manually if python3 fails
  SAFE_REASON=$(echo "$REASON" | sed 's/"/\\"/g')
  echo "{\"session_id\":\"$SESSION_ID\",\"reason\":\"$SAFE_REASON\",\"timestamp\":\"$TIMESTAMP\",\"had_lock\":$HAS_LOCK,\"had_state\":$HAS_STATE,\"slices_completed\":$SLICES_COMPLETED,\"slices_total\":$SLICES_TOTAL}" >> "$DISCARD_LOG"
fi

# ── Clean lock file ──────────────────────────────────────────────────────────
if [[ "$HAS_LOCK" == "true" ]]; then
  rm -f "$LOCK_FILE"
  echo "  Removed lock: $LOCK_FILE"
fi

# ── Archive state file ───────────────────────────────────────────────────────
if [[ "$HAS_STATE" == "true" ]]; then
  mv "$STATE_FILE" "${STATE_FILE}.discarded"
  echo "  Archived state: ${STATE_FILE}.discarded"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo "OK: session '$SESSION_ID' discarded"
echo "  Reason: $REASON"
echo "  Lock removed: $HAS_LOCK"
echo "  State archived: $HAS_STATE"
echo "  Slices completed: $SLICES_COMPLETED/$SLICES_TOTAL"
exit 0
