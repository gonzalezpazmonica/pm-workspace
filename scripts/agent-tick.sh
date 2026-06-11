#!/usr/bin/env bash
set -uo pipefail
# agent-tick.sh — SE-219 S5: light/heavy tick separation (abtop tick_no_summaries pattern)
# Ref: docs/propuestas/SE-219-abtop-patterns.md
# Usage: agent-tick.sh --mode light|heavy | --status
# Exit: 0 always

AGENT_HEAVY_TICK_INTERVAL="${AGENT_HEAVY_TICK_INTERVAL:-300}"
TICK_STATE_FILE="${AGENT_TICK_STATE:-output/.agent-tick-state.json}"

# ── Ensure state directory exists ─────────────────────────────────────────────
_ensure_state_dir() {
  local dir
  dir="$(dirname "$TICK_STATE_FILE")"
  if [[ -n "$dir" && "$dir" != "." ]]; then
    mkdir -p "$dir" 2>/dev/null || true
  fi
}

# ── Read last heavy tick timestamp from state file ────────────────────────────
_read_last_heavy() {
  if [[ ! -f "$TICK_STATE_FILE" ]]; then
    echo ""
    return
  fi
  python3 - "$TICK_STATE_FILE" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get("last_heavy_ts",""))
except Exception:
    print("")
PY
}

# ── Write state file ──────────────────────────────────────────────────────────
_write_state() {
  local mode="$1" cost="$2" last_heavy="${3:-}"
  _ensure_state_dir
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
  python3 - "$TICK_STATE_FILE" "$mode" "$cost" "$last_heavy" "$ts" <<'PY' 2>/dev/null
import json, sys
path, mode, cost, last_heavy, ts = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
state = {}
try:
    state = json.load(open(path))
except Exception:
    pass
state["mode"]     = mode
state["cost"]     = cost
state["ts"]       = ts
if last_heavy:
    state["last_heavy_ts"] = last_heavy
elif "last_heavy_ts" not in state:
    state["last_heavy_ts"] = ""
with open(path, "w") as f:
    json.dump(state, f)
PY
}

# ── Seconds since epoch (portable) ───────────────────────────────────────────
_epoch() {
  date +%s 2>/dev/null || python3 -c "import time; print(int(time.time()))"
}

# ── Parse ISO8601 UTC timestamp to epoch seconds ──────────────────────────────
_ts_to_epoch() {
  local ts="$1"
  [[ -z "$ts" ]] && echo 0 && return
  python3 - "$ts" <<'PY' 2>/dev/null
import sys
from datetime import datetime, timezone
ts = sys.argv[1]
try:
    dt = datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    print(int(dt.timestamp()))
except Exception:
    print(0)
PY
}

# ── Sub-commands ──────────────────────────────────────────────────────────────
cmd_light() {
  _ensure_state_dir
  _write_state "light" "low" ""
  echo "TICK_MODE=light"
  echo "TICK_COST=low"
}

cmd_heavy() {
  _ensure_state_dir
  local last_heavy
  last_heavy=$(_read_last_heavy)
  local now
  now=$(_epoch)

  if [[ -n "$last_heavy" ]]; then
    local last_epoch
    last_epoch=$(_ts_to_epoch "$last_heavy")
    local elapsed=$(( now - last_epoch ))

    # If interval > 0 and not enough time has passed, skip
    if [[ "$AGENT_HEAVY_TICK_INTERVAL" -gt 0 && "$elapsed" -lt "$AGENT_HEAVY_TICK_INTERVAL" ]]; then
      echo "TICK_SKIPPED=true"
      echo "TICK_REASON=interval_not_elapsed"
      exit 0
    fi
  fi

  # Proceed with heavy tick
  local new_ts
  new_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
  _write_state "heavy" "high" "$new_ts"
  echo "TICK_MODE=heavy"
  echo "TICK_COST=high"
}

cmd_status() {
  if [[ ! -f "$TICK_STATE_FILE" ]]; then
    echo "TICK_MODE=unknown"
    echo "TICK_COST=unknown"
    echo "LAST_HEAVY_TICK="
    echo "HEAVY_TICK_INTERVAL=${AGENT_HEAVY_TICK_INTERVAL}"
    exit 0
  fi

  python3 - "$TICK_STATE_FILE" "$AGENT_HEAVY_TICK_INTERVAL" <<'PY' 2>/dev/null
import json, sys
path, interval = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(path))
    print(f"TICK_MODE={d.get('mode','unknown')}")
    print(f"TICK_COST={d.get('cost','unknown')}")
    print(f"LAST_HEAVY_TICK={d.get('last_heavy_ts','')}")
    print(f"HEAVY_TICK_INTERVAL={interval}")
except Exception:
    print("TICK_MODE=unknown")
    print("TICK_COST=unknown")
    print("LAST_HEAVY_TICK=")
    print(f"HEAVY_TICK_INTERVAL={interval}")
PY
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:?--mode requires light|heavy}"
      shift 2 ;;
    --status)
      cmd_status
      exit 0 ;;
    --help|-h)
      echo "Usage: agent-tick.sh --mode light|heavy | --status"
      exit 0 ;;
    *) shift ;;
  esac
done

case "$MODE" in
  light)  cmd_light ;;
  heavy)  cmd_heavy ;;
  "")
    echo "Usage: agent-tick.sh --mode light|heavy | --status" >&2
    exit 0 ;;
  *)
    echo "ERROR: invalid mode '${MODE}'. Use light or heavy." >&2
    exit 2 ;;
esac

exit 0
