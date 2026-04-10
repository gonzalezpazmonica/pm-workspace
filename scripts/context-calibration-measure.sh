#!/usr/bin/env bash
# context-calibration-measure.sh — Measure context usage patterns
# SPEC-AUTOCOMPACT-CALIBRATION: tools for measuring Brier score of
# context-usage quality before and after calibration changes.
#
# Usage: bash scripts/context-calibration-measure.sh [options]
#
# Options:
#   --log FILE      Context usage log file (default: output/context-usage.log)
#   --since DATE    Filter entries since YYYY-MM-DD (default: all)
#   --output FILE   Output report file (default: output/context-calibration-YYYYMMDD.md)
#   --help          Show this help
#
# Exit: 0 success, 1 log not found, 2 invalid args

set -uo pipefail

LOG_FILE="output/context-usage.log"
SINCE=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log)
      [[ $# -lt 2 ]] && { echo "Error: --log requires a file path" >&2; exit 2; }
      LOG_FILE="$2"; shift 2 ;;
    --since)
      [[ $# -lt 2 ]] && { echo "Error: --since requires a date" >&2; exit 2; }
      SINCE="$2"; shift 2 ;;
    --output)
      [[ $# -lt 2 ]] && { echo "Error: --output requires a file path" >&2; exit 2; }
      OUTPUT_FILE="$2"; shift 2 ;;
    --help|-h)
      sed -n '2,15p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *)
      echo "Error: unknown option $1" >&2
      exit 2 ;;
  esac
done

if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="output/context-calibration-$(date +%Y%m%d).md"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")" 2>/dev/null || true

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Log file not found: $LOG_FILE" >&2
  echo "Expected format: timestamp|command|usage_pct|tokens_used" >&2
  exit 1
fi

# Filter by --since if provided
filter_logs() {
  if [[ -n "$SINCE" ]]; then
    awk -F'|' -v since="$SINCE" '$1 >= since' "$LOG_FILE"
  else
    cat "$LOG_FILE"
  fi
}

# Compute statistics
compute_stats() {
  local total=0 sum=0 max=0 compact_triggers=0
  while IFS='|' read -r ts cmd usage tokens; do
    [[ -z "$usage" ]] && continue
    usage_int=${usage%%.*}
    total=$((total + 1))
    sum=$((sum + usage_int))
    [[ $usage_int -gt $max ]] && max=$usage_int
    [[ $usage_int -ge 75 ]] && compact_triggers=$((compact_triggers + 1))
  done < <(filter_logs)

  if [[ $total -eq 0 ]]; then
    echo "0 0 0 0"
    return
  fi

  local avg=$((sum / total))
  echo "$total $avg $max $compact_triggers"
}

generate_report() {
  local stats="$1"
  read -r total avg max compact_triggers <<< "$stats"

  local since_label="${SINCE:-all}"

  cat > "$OUTPUT_FILE" <<REPORT
# Context Calibration Measurement

- Log file: $LOG_FILE
- Since: $since_label
- Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Statistics

- Total entries: $total
- Average context usage: $avg%
- Peak context usage: $max%
- Compact triggers (>=75%): $compact_triggers

## Calibration

- Current AUTOCOMPACT threshold: 75% (SPEC-AUTOCOMPACT-CALIBRATION)
- Prior AUTOCOMPACT threshold: 65% (v4.32 and earlier)

## Interpretation

- Avg < 50%: workspace idle or light sessions — threshold has no impact
- Avg 50-70%: gradual zone — sessions normally working, no blocking
- Avg 70-85%: alert zone — approaching the 75% calibrated threshold
- Avg > 85%: critical — calibration may be too permissive, review

## Notes

This measurement requires a populated log file at $LOG_FILE.
Log format expected: timestamp|command|usage_pct|tokens_used
REPORT
}

STATS=$(compute_stats)
generate_report "$STATS"

echo "Report generated: $OUTPUT_FILE"
echo "$STATS" | awk '{printf "Entries: %d | Avg: %d%% | Max: %d%% | Triggers: %d\n", $1, $2, $3, $4}'
