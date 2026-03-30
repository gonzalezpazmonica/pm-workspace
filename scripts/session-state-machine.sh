#!/usr/bin/env bash
set -uo pipefail
# session-state-machine.sh — SPEC-051 Phase 1: Session State Machine
# Usage: session-state-machine.sh --session-id ID (--transition EVENT | --status | --init)

SESSIONS_DIR="${SESSIONS_DIR:-output/dev-sessions}"
SESSION_ID="" TRANSITION="" MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) echo "Usage: $0 --session-id ID (--transition EVENT | --status | --init)"
               echo "Manage dev-session state transitions (spawning -> implementing -> ... -> merged)."
               exit 0 ;;
    --session-id) SESSION_ID="$2"; shift 2 ;;
    --transition) TRANSITION="$2"; MODE="transition"; shift 2 ;;
    --status) MODE="status"; shift ;;
    --init) MODE="init"; shift ;;
    *) echo "Usage: $0 --session-id ID (--transition EVENT | --status | --init)" >&2; exit 1 ;;
  esac
done
[[ -z "$SESSION_ID" || -z "$MODE" ]] && { echo "ERROR: --session-id and mode required" >&2; exit 1; }

STATE_FILE="$SESSIONS_DIR/$SESSION_ID/state.json"
TRACE_FILE="$SESSIONS_DIR/$SESSION_ID/transitions.jsonl"

emit_trace() {
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$(dirname "$TRACE_FILE")"
  printf '{"event":"state_transition","session":"%s","from":"%s","to":"%s","at":"%s"}\n' \
    "$SESSION_ID" "$1" "$2" "$ts" >> "$TRACE_FILE"
}

case "$MODE" in
  init)
    mkdir -p "$(dirname "$STATE_FILE")"
    local_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '{"session_id":"%s","status":"spawning","previous_status":null,"status_changed_at":"%s","transitions":[]}\n' \
      "$SESSION_ID" "$local_ts" > "$STATE_FILE"
    emit_trace "null" "spawning"
    echo "OK: session $SESSION_ID initialized as spawning"
    ;;
  status)
    [[ ! -f "$STATE_FILE" ]] && { echo "ERROR: session $SESSION_ID not found" >&2; exit 1; }
    python3 -c "import json; print(json.load(open('$STATE_FILE')).get('status','unknown'))"
    ;;
  transition)
    [[ ! -f "$STATE_FILE" ]] && { echo "ERROR: session $SESSION_ID not found" >&2; exit 1; }
    [[ -z "$TRANSITION" ]] && { echo "ERROR: --transition requires target state" >&2; exit 1; }
    SSM_STATE_FILE="$STATE_FILE" SSM_TARGET="$TRANSITION" python3 -c "
import json, sys, os
from datetime import datetime, timezone
VALID = {
    'spawning': ['context-loading', 'discarded'],
    'context-loading': ['implementing', 'discarded'],
    'implementing': ['validating', 'discarded'],
    'validating': ['verified', 'implementing', 'discarded'],
    'verified': ['reviewing', 'discarded'],
    'reviewing': ['changes-requested', 'ci-running', 'discarded'],
    'changes-requested': ['implementing', 'discarded'],
    'ci-running': ['ci-failed', 'ci-passed', 'discarded'],
    'ci-failed': ['implementing', 'discarded'],
    'ci-passed': ['merging', 'discarded'],
    'merging': ['merged', 'discarded'],
    'merged': [], 'discarded': [],
}
state_file, target = os.environ['SSM_STATE_FILE'], os.environ['SSM_TARGET']
try:
    with open(state_file) as f:
        state = json.load(f)
except (json.JSONDecodeError, FileNotFoundError) as e:
    print(f'ERROR: cannot read state: {e}', file=sys.stderr); sys.exit(1)
current = state.get('status', 'unknown')
if current not in VALID:
    print(f'ERROR: state \"{current}\" is terminal or unknown', file=sys.stderr); sys.exit(2)
allowed = VALID[current]
if target not in allowed:
    print(f'ERROR: invalid transition {current} -> {target}. Allowed: {allowed}', file=sys.stderr)
    sys.exit(2)
now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
state['previous_status'] = current
state['status'] = target
state['status_changed_at'] = now
hist = state.get('transitions', [])
hist.append({'from': current, 'to': target, 'at': now})
if len(hist) > 50:
    hist = hist[-50:]
state['transitions'] = hist
with open(state_file, 'w') as f:
    json.dump(state, f)
print(f'OK: {current} -> {target}')
" || exit $?
    prev=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('previous_status','unknown'))")
    emit_trace "$prev" "$TRANSITION"
    ;;
esac
