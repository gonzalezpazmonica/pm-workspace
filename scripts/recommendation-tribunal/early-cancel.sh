#!/usr/bin/env bash
set -uo pipefail
# early-cancel.sh — SPEC-196: Freeze-done elements en Recommendation Tribunal.
#
# Polls a directory where judge processes write their JSON outputs. When any
# judge emits veto:true AND confidence>=THRESHOLD, kills the remaining judge
# PIDs and exits with a summary of what was cancelled.
#
# Pattern: equivalent to _WhileLoopCarry.done in DiffusionGemma — when one
# batch element is "done" (here: VETO determined), the others can stop.
#
# Usage:
#   early-cancel.sh \
#       --judges-dir DIR \
#       --pids PID1,PID2,...,PIDN \
#       --names NAME1,NAME2,...,NAMEN \
#       [--threshold 0.95] \
#       [--max-wait 5] \
#       [--poll-ms 200]
#
# Expects each judge to write its JSON to DIR/<NAME>.json when complete.
# Each JSON must contain `veto` (bool) and `confidence` (float).
#
# Output (stdout, JSON):
#   { "early_cancel": bool, "cancelled_judges": [str], "wall_clock_s": float,
#     "trigger": { "judge": str, "confidence": float } | null }
#
# Exit codes:
#   0  ok (early cancel triggered OR all judges completed naturally OR max-wait)
#   2  bad args
#
# Reference: SPEC-196 docs/propuestas/SPEC-196-tribunal-freeze-done-elements.md

# Master switches
[[ "${SAVIA_TRIBUNAL_EARLY_CANCEL:-on}" == "off" ]] && {
  echo '{"early_cancel":false,"cancelled_judges":[],"wall_clock_s":0,"trigger":null,"disabled":true}'
  exit 0
}

THRESHOLD="${SAVIA_TRIBUNAL_EARLY_CANCEL_THRESHOLD:-0.95}"
POLL_MS="${SAVIA_TRIBUNAL_EARLY_CANCEL_POLL_MS:-200}"
MAX_WAIT_S=5
JUDGES_DIR=""
PIDS_CSV=""
NAMES_CSV=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --judges-dir) JUDGES_DIR="$2"; shift 2 ;;
    --pids) PIDS_CSV="$2"; shift 2 ;;
    --names) NAMES_CSV="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --max-wait) MAX_WAIT_S="$2"; shift 2 ;;
    --poll-ms) POLL_MS="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$JUDGES_DIR" || -z "$PIDS_CSV" || -z "$NAMES_CSV" ]]; then
  echo "ERROR: --judges-dir, --pids and --names are required" >&2
  exit 2
fi

if [[ ! -d "$JUDGES_DIR" ]]; then
  echo "ERROR: judges-dir does not exist: $JUDGES_DIR" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  # Fail-soft: emit no-op result
  echo '{"early_cancel":false,"cancelled_judges":[],"wall_clock_s":0,"trigger":null,"reason":"jq_missing"}'
  exit 0
fi

# Parse CSVs into bash arrays
IFS=',' read -ra PIDS <<< "$PIDS_CSV"
IFS=',' read -ra NAMES <<< "$NAMES_CSV"

if [[ ${#PIDS[@]} -ne ${#NAMES[@]} ]]; then
  echo "ERROR: number of --pids must match --names" >&2
  exit 2
fi

declare -A PID_OF
declare -A COMPLETED
for i in "${!NAMES[@]}"; do
  PID_OF["${NAMES[$i]}"]="${PIDS[$i]}"
done

export LC_NUMERIC=C  # force '.' as decimal separator regardless of locale
start_ts=$(date +%s.%N 2>/dev/null || date +%s)
poll_seconds=$(awk -v ms="$POLL_MS" 'BEGIN{printf "%.3f", ms/1000.0}')

cancelled=()
trigger_judge=""
trigger_conf="0"
early_cancel="false"

while :; do
  now=$(date +%s.%N 2>/dev/null || date +%s)
  elapsed=$(awk -v a="$now" -v b="$start_ts" 'BEGIN{printf "%.3f", a-b}')
  if awk -v e="$elapsed" -v m="$MAX_WAIT_S" 'BEGIN{exit !(e+0 >= m+0)}'; then
    break
  fi

  # Check each judge that has not been processed yet
  any_pending=false
  for name in "${NAMES[@]}"; do
    [[ -n "${COMPLETED[$name]:-}" ]] && continue
    any_pending=true
    f="$JUDGES_DIR/$name.json"
    if [[ -f "$f" ]]; then
      # Validate JSON before parsing
      if jq -e . "$f" >/dev/null 2>&1; then
        COMPLETED["$name"]="1"
        veto=$(jq -r '.veto // false' "$f" 2>/dev/null)
        conf=$(jq -r '.confidence // 0' "$f" 2>/dev/null)
        if [[ "$veto" == "true" ]] && \
           awk -v c="$conf" -v t="$THRESHOLD" 'BEGIN{exit !(c+0 >= t+0)}'; then
          # Trigger early-cancel
          trigger_judge="$name"
          trigger_conf="$conf"
          early_cancel="true"
          # Kill remaining PIDs
          for nm in "${NAMES[@]}"; do
            [[ -n "${COMPLETED[$nm]:-}" ]] && continue
            kill -TERM "${PID_OF[$nm]}" 2>/dev/null || true
            cancelled+=("$nm")
            COMPLETED["$nm"]="cancelled"
          done
          # Give them 1s to die gracefully, then SIGKILL
          sleep 1
          for nm in "${cancelled[@]}"; do
            kill -KILL "${PID_OF[$nm]}" 2>/dev/null || true
          done
          break 2
        fi
      fi
    fi
  done

  [[ "$any_pending" == "false" ]] && break

  sleep "$poll_seconds"
done

now=$(date +%s.%N 2>/dev/null || date +%s)
wall_clock=$(awk -v a="$now" -v b="$start_ts" 'BEGIN{printf "%.3f", a-b}')

# Build cancelled_judges JSON array
cancelled_json="["
first=true
for c in "${cancelled[@]:-}"; do
  [[ -z "$c" ]] && continue
  $first || cancelled_json+=","
  cancelled_json+="\"$c\""
  first=false
done
cancelled_json+="]"

# Build trigger object
if [[ "$early_cancel" == "true" ]]; then
  trigger_json="{\"judge\":\"$trigger_judge\",\"confidence\":$trigger_conf}"
else
  trigger_json="null"
fi

printf '{"early_cancel":%s,"cancelled_judges":%s,"wall_clock_s":%s,"trigger":%s,"threshold":%s}\n' \
  "$early_cancel" "$cancelled_json" "$wall_clock" "$trigger_json" "$THRESHOLD"
