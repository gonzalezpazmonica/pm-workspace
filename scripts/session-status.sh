#!/usr/bin/env bash
set -uo pipefail
# session-status.sh — SE-219 S1: consultable session snapshot (abtop pattern)
# Ref: docs/propuestas/SE-219-abtop-patterns.md
# Usage: session-status.sh [--json] [--once]
# Exit: 0 always

LOG_FILE="${SESSION_ACTION_LOG:-output/session-action-log.jsonl}"
SESSION_ID="${SESSION_ACTION_SESSION:-$$}"

MODE="table"
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --json)  MODE="json";  shift ;;
    --once)  MODE="once";  shift ;;
    --help|-h)
      echo "Usage: session-status.sh [--json] [--once]"
      exit 0 ;;
    *) shift ;;
  esac
done

# --- aggregate stats via python3 ---
SNAPSHOT=$(python3 - "$LOG_FILE" "$SESSION_ID" <<'PY'
import sys, json, os

log_file   = sys.argv[1]
session_id = sys.argv[2]

actions_total       = 0
actions_pass        = 0
actions_fail        = 0
consecutive_failures= 0
last_action         = {}
log_size            = 0
started_at          = ""
resolved_session    = session_id

if os.path.isfile(log_file):
    log_size = os.path.getsize(log_file)
    entries = []
    with open(log_file, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except Exception:
                continue
            entries.append(entry)

    if entries:
        last_action = entries[-1]
        resolved_session = last_action.get("session", session_id)
        started_at = entries[0].get("ts", "")

    for entry in entries:
        actions_total += 1
        result = entry.get("result", "")
        if result in ("pass", "ok"):
            actions_pass += 1
        elif result in ("fail", "error"):
            actions_fail += 1

    # consecutive failures = trailing failures without a pass
    for entry in reversed(entries):
        result = entry.get("result", "")
        if result in ("pass", "ok"):
            break
        if result in ("fail", "error"):
            consecutive_failures += 1
        # unknown result: keep counting? no — stop
        else:
            break

out = {
    "session_id":           resolved_session,
    "started_at":           started_at,
    "actions_total":        actions_total,
    "actions_pass":         actions_pass,
    "actions_fail":         actions_fail,
    "consecutive_failures": consecutive_failures,
    "last_action":          last_action,
    "log_file":             log_file,
    "log_size_bytes":       log_size,
}
print(json.dumps(out))
PY
)

if [[ "$MODE" == "json" ]]; then
  echo "$SNAPSHOT"
  exit 0
fi

# table / once
python3 - "$SNAPSHOT" <<'PY'
import sys, json
data = json.loads(sys.argv[1])
print(f"Session : {data['session_id']}")
print(f"Started : {data['started_at'] or 'unknown'}")
print(f"Total   : {data['actions_total']}  Pass: {data['actions_pass']}  Fail: {data['actions_fail']}")
print(f"Consec. failures: {data['consecutive_failures']}")
la = data.get("last_action") or {}
if la:
    print(f"Last    : {la.get('action','')} -> {la.get('result','')} @ {la.get('ts','')}")
else:
    print("Last    : (none)")
print(f"Log     : {data['log_file']}  ({data['log_size_bytes']} bytes)")
PY

exit 0
