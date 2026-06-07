#!/bin/bash
# agent-wait-idle.sh — SE-206: detect when an AI agent process is idle
# Inspired by Orca's 'terminal wait --for tui-idle' pattern
# Ref: docs/rules/domain/agent-idle-protocol.md
set -uo pipefail

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<'USAGE'
Usage: agent-wait-idle.sh --pid <PID> [OPTIONS]

Wait until an AI agent process becomes idle (no output activity).

Required:
  --pid <PID>              PID of the agent process to monitor

Options:
  --timeout <seconds>      Maximum wait time (default: 300)
  --poll-interval <sec>    Polling frequency in seconds (default: 2)
  --idle-threshold <sec>   Silence duration to declare idle (default: 5)
  --log <file>             Log file the agent writes to (enables file-mtime mode)
  --json                   Emit JSON: {"status":"idle|timeout|dead","elapsed":N,"pid":N}
  --dry-run                Show what would happen without waiting
  --help                   Show this help

Exit codes:
  0 = agent idle (ready for next task)
  1 = timeout reached (agent still active)
  2 = process dead or PID not found
  3 = usage error (invalid/missing arguments)

Examples:
  agent-wait-idle.sh --pid 12345
  agent-wait-idle.sh --pid 12345 --timeout 120 --idle-threshold 10
  agent-wait-idle.sh --pid 12345 --log /tmp/agent.log --json
  agent-wait-idle.sh --pid $$ --dry-run
USAGE
}

# ── Defaults ─────────────────────────────────────────────────────────────────
PID=""
TIMEOUT=300
POLL_INTERVAL=2
IDLE_THRESHOLD=5
LOG_FILE=""
JSON_OUTPUT=false
DRY_RUN=false

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pid)
      [[ -z "${2:-}" ]] && { echo "ERROR: --pid requires a value" >&2; exit 3; }
      PID="$2"; shift 2 ;;
    --timeout)
      [[ -z "${2:-}" ]] && { echo "ERROR: --timeout requires a value" >&2; exit 3; }
      TIMEOUT="$2"; shift 2 ;;
    --poll-interval)
      [[ -z "${2:-}" ]] && { echo "ERROR: --poll-interval requires a value" >&2; exit 3; }
      POLL_INTERVAL="$2"; shift 2 ;;
    --idle-threshold)
      [[ -z "${2:-}" ]] && { echo "ERROR: --idle-threshold requires a value" >&2; exit 3; }
      IDLE_THRESHOLD="$2"; shift 2 ;;
    --log)
      [[ -z "${2:-}" ]] && { echo "ERROR: --log requires a value" >&2; exit 3; }
      LOG_FILE="$2"; shift 2 ;;
    --json)
      JSON_OUTPUT=true; shift ;;
    --dry-run)
      DRY_RUN=true; shift ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2; exit 3 ;;
  esac
done

# ── Validate required args ───────────────────────────────────────────────────
if [[ -z "$PID" ]]; then
  echo "ERROR: --pid is required" >&2
  usage >&2
  exit 3
fi

# Validate PID is a positive integer
if ! [[ "$PID" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --pid must be a positive integer, got: $PID" >&2
  exit 3
fi

# PID 0 is the process group — not a valid agent PID
if [[ "$PID" -eq 0 ]]; then
  echo "ERROR: PID 0 is not a valid agent PID" >&2
  exit 3
fi

# ── Helper: emit result ──────────────────────────────────────────────────────
emit_result() {
  local status="$1"
  local elapsed="$2"
  if $JSON_OUTPUT; then
    printf '{"status":"%s","elapsed":%d,"pid":%d}\n' "$status" "$elapsed" "$PID"
  else
    echo "agent-wait-idle: status=$status elapsed=${elapsed}s pid=$PID"
  fi
}

# ── Dry-run mode ─────────────────────────────────────────────────────────────
if $DRY_RUN; then
  echo "DRY-RUN agent-wait-idle.sh:"
  echo "  pid=$PID timeout=${TIMEOUT}s poll=${POLL_INTERVAL}s idle-threshold=${IDLE_THRESHOLD}s"
  if [[ -n "$LOG_FILE" ]]; then
    echo "  mode=log-mtime log=$LOG_FILE"
  else
    echo "  mode=proc-fdinfo (/proc/$PID/fdinfo)"
  fi
  echo "  json=$JSON_OUTPUT"
  exit 0
fi

# ── Check process exists ─────────────────────────────────────────────────────
if ! kill -0 "$PID" 2>/dev/null; then
  emit_result "dead" 0
  exit 2
fi

# ── Activity sampling ─────────────────────────────────────────────────────────
# Mode A: track log file mtime (preferred — accurate, no /proc dependency)
# Mode B: poll /proc/PID/fdinfo pos fields (Linux fallback when no log given)
_get_activity_value() {
  if [[ -n "$LOG_FILE" ]]; then
    # Mode A: log file mtime as seconds since epoch
    if [[ -e "$LOG_FILE" ]]; then
      stat -c '%Y' "$LOG_FILE" 2>/dev/null || echo "0"
    else
      # Log file does not yet exist — no activity
      echo "0"
    fi
  else
    # Mode B: sum of fd position values from /proc/PID/fdinfo
    # A write advances the pos counter; sum change signals I/O activity
    local fdinfo_dir="/proc/$PID/fdinfo"
    if [[ -d "$fdinfo_dir" ]]; then
      awk '/^pos:/{sum+=$2} END{print sum+0}' "$fdinfo_dir"/* 2>/dev/null || echo "0"
    else
      echo "0"
    fi
  fi
}

# ── Main wait loop ─────────────────────────────────────────────────────────────
START_EPOCH=$(date +%s)
IDLE_SINCE=0
LAST_ACTIVITY_VAL=""

while true; do
  NOW=$(date +%s)
  ELAPSED=$(( NOW - START_EPOCH ))

  # Check process still alive
  if ! kill -0 "$PID" 2>/dev/null; then
    emit_result "dead" "$ELAPSED"
    exit 2
  fi

  # Check global timeout
  if [[ $ELAPSED -ge $TIMEOUT ]]; then
    emit_result "timeout" "$ELAPSED"
    exit 1
  fi

  # Sample current activity marker
  CURRENT_VAL=$(_get_activity_value)

  if [[ "$CURRENT_VAL" != "$LAST_ACTIVITY_VAL" ]]; then
    # Activity detected — reset idle clock
    LAST_ACTIVITY_VAL="$CURRENT_VAL"
    IDLE_SINCE=$NOW
  else
    # No change — check how long we have been idle
    if [[ $IDLE_SINCE -gt 0 ]]; then
      IDLE_DURATION=$(( NOW - IDLE_SINCE ))
      if [[ $IDLE_DURATION -ge $IDLE_THRESHOLD ]]; then
        emit_result "idle" "$ELAPSED"
        exit 0
      fi
    fi
  fi

  sleep "$POLL_INTERVAL"
done
