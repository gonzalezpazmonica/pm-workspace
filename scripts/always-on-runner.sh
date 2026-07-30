#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C
# always-on-runner.sh — Scheduled Monitoring Detector Framework (SE-279)
#
# Two-phase design:
#   Phase 1 (bash, no LLM): run detector script → JSON output
#   Phase 2 (LLM, only if triggered): generate human-readable report
#
# NEVER modifies code, branches, or backlog. Only writes to output/always-on/.
#
# Usage: always-on-runner.sh <detector-id> [--once] [--detect-only]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DETECTORS_DIR="${SCRIPT_DIR}/always-on/detectors"
REPORTERS_DIR="${SCRIPT_DIR}/always-on/reporters"
OUTPUT_DIR="${ROOT}/output/always-on"
STATE_DIR="${OUTPUT_DIR}/state"

mkdir -p "$OUTPUT_DIR" "$STATE_DIR"

die() { echo "ERROR: $*" >&2; exit 1; }

DETECTOR_ID="${1:-}"
ONCE=false
DETECT_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --once) ONCE=true; shift ;;
    --detect-only) DETECT_ONLY=true; shift ;;
    --help|-h)
      echo "Usage: always-on-runner.sh <detector-id> [--once] [--detect-only]"
      echo ""
      echo "Detectors:"
      for f in "$DETECTORS_DIR"/*.sh; do
        [[ -f "$f" ]] || continue
        local name; name=$(basename "$f" .sh)
        echo "  $name"
      done
      exit 0
      ;;
    *) DETECTOR_ID="$1"; shift ;;
  esac
done

[[ -z "$DETECTOR_ID" ]] && die "detector-id required"

DETECTOR_SCRIPT="${DETECTORS_DIR}/${DETECTOR_ID}.sh"
REPORTER_SCRIPT="${REPORTERS_DIR}/generic-alert.sh"
STATE_FILE="${STATE_DIR}/${DETECTOR_ID}-state.json"
COOLDOWN_MINUTES="${ALWAYS_ON_COOLDOWN_MINUTES:-120}"
MAX_CONSECUTIVE_FAILURES=3

[[ -f "$DETECTOR_SCRIPT" ]] || die "Detector not found: $DETECTOR_SCRIPT"

# --- State management ---
read_state() {
  if [[ -f "$STATE_FILE" ]]; then
    cat "$STATE_FILE"
  else
    echo '{"last_run":null,"last_alert":null,"consecutive_failures":0,"disabled":false}'
  fi
}

write_state() {
  echo "$1" > "$STATE_FILE"
}

# --- Cooldown check ---
check_cooldown() {
  local state last_alert now elapsed
  state=$(read_state)
  last_alert=$(echo "$state" | python3 -c "import sys,json; print(json.load(sys.stdin).get('last_alert','null'))" 2>/dev/null || echo "null")

  if [[ "$last_alert" != "null" ]]; then
    now=$(date +%s)
    last_alert_epoch=$(date -d "$last_alert" +%s 2>/dev/null || echo 0)
    elapsed=$(( (now - last_alert_epoch) / 60 ))
    if [[ $elapsed -lt $COOLDOWN_MINUTES ]]; then
      return 1  # in cooldown
    fi
  fi
  return 0  # not in cooldown
}

# --- Main ---
state=$(read_state)
disabled=$(echo "$state" | python3 -c "import sys,json; print(json.load(sys.stdin).get('disabled',False))" 2>/dev/null || echo "false")

if [[ "$disabled" == "True" ]] && ! $ONCE; then
  echo "{\"detector\":\"$DETECTOR_ID\",\"status\":\"disabled\",\"reason\":\"max consecutive failures reached\"}"
  exit 0
fi

# Phase 1: Run detector (bash, no LLM)
DETECT_OUTPUT=$(bash "$DETECTOR_SCRIPT" 2>/dev/null || echo '{"error":"detector failed"}')
DETECT_EXIT=$?

TRIGGERED=$(echo "$DETECT_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('triggered',False))" 2>/dev/null || echo "False")

# Update state
now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if [[ $DETECT_EXIT -ne 0 ]] || echo "$DETECT_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('error') else 1)" 2>/dev/null; then
  # Detector failed
  failures=$(echo "$state" | python3 -c "import sys,json; print(json.load(sys.stdin).get('consecutive_failures',0)+1)" 2>/dev/null || echo 1)
  new_disabled="false"
  if [[ $failures -ge $MAX_CONSECUTIVE_FAILURES ]]; then
    new_disabled="true"
  fi
  new_state=$(python3 -c "
import json
print(json.dumps({
    'last_run': '$now_iso',
    'last_alert': None,
    'consecutive_failures': $failures,
    'disabled': $new_disabled
}))
" 2>/dev/null)
  write_state "$new_state"
  echo "{\"detector\":\"$DETECTOR_ID\",\"status\":\"error\",\"failures\":$failures,\"disabled\":$new_disabled}"
  exit $DETECT_EXIT
fi

# Reset failures on success
state=$(echo "$state" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['last_run'] = '$now_iso'
d['consecutive_failures'] = 0
print(json.dumps(d))
" 2>/dev/null)
write_state "$state"

if [[ "$TRIGGERED" != "True" ]]; then
  echo "{\"detector\":\"$DETECTOR_ID\",\"status\":\"clear\",\"triggered\":false}"
  exit 0
fi

# Cooldown check (skip if --once)
if ! $ONCE && ! check_cooldown; then
  echo "{\"detector\":\"$DETECTOR_ID\",\"status\":\"cooldown\",\"triggered\":true}"
  exit 0
fi

if $DETECT_ONLY; then
  echo "$DETECT_OUTPUT"
  exit 0
fi

# Phase 2: Generate report (LLM, only if triggered)
REPORT_DATE=$(date +%Y%m%d-%H%M)
REPORT_FILE="${OUTPUT_DIR}/${DETECTOR_ID}-${REPORT_DATE}.md"

if [[ -f "$REPORTER_SCRIPT" ]]; then
  bash "$REPORTER_SCRIPT" \
    --detector "$DETECTOR_ID" \
    --data "$DETECT_OUTPUT" \
    --output "$REPORT_FILE" 2>/dev/null || {
      # Fallback: basic markdown report without LLM
      {
        echo "# $DETECTOR_ID — Alert"
        echo ""
        echo "**Date**: $(date) | **Detector**: $DETECTOR_ID"
        echo ""
        echo '```json'
        echo "$DETECT_OUTPUT"
        echo '```'
      } > "$REPORT_FILE"
    }
else
  {
    echo "# $DETECTOR_ID — Alert"
    echo ""
    echo "**Date**: $(date) | **Detector**: $DETECTOR_ID"
    echo ""
    echo '```json'
    echo "$DETECT_OUTPUT"
    echo '```'
  } > "$REPORT_FILE"
fi

# Update alert timestamp
state=$(read_state)
state=$(echo "$state" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['last_alert'] = '$now_iso'
print(json.dumps(d))
" 2>/dev/null)
write_state "$state"

echo "{\"detector\":\"$DETECTOR_ID\",\"status\":\"alert\",\"triggered\":true,\"report\":\"$REPORT_FILE\"}"
