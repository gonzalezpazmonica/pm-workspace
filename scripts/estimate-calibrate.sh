#!/usr/bin/env bash
# estimate-calibrate.sh — Recompute empirical agent speedups from actuals log
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-013-dual-estimation.md
#
# Reads data/agent-actuals.jsonl (or $AGENT_ACTUALS_LOG), groups entries by
# category, computes empirical speedup (human_hours / agent_wallclock_hours),
# and compares against the default table from dual-estimation.md. Suggests
# adjustments only when sample count per category >= DUAL_ESTIMATION_MIN_SAMPLES.
#
# Usage:
#   bash scripts/estimate-calibrate.sh
#   bash scripts/estimate-calibrate.sh --format json
#   bash scripts/estimate-calibrate.sh --log path/to/custom.jsonl
#
# Exit codes:
#   0  success (or empty log — prints "No samples" message)
#   1  invalid arguments
#   2  jq not installed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEFAULT_LOG="${AGENT_ACTUALS_LOG:-data/agent-actuals.jsonl}"
LOG_PATH="$PROJECT_ROOT/$DEFAULT_LOG"
FORMAT="banner"
MIN_SAMPLES="${DUAL_ESTIMATION_MIN_SAMPLES:-10}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="${2:-banner}"
      shift 2
      ;;
    --format=*)
      FORMAT="${1#*=}"
      shift
      ;;
    --log)
      LOG_PATH="${2:-}"
      shift 2
      ;;
    --log=*)
      LOG_PATH="${1#*=}"
      shift
      ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed" >&2
  exit 2
fi

if [[ ! -f "$LOG_PATH" ]]; then
  if [[ "$FORMAT" == "json" ]]; then
    printf '{"samples":0,"message":"No samples yet. Start tracking via %s."}\n' "$DEFAULT_LOG"
  else
    echo "No samples yet. Start tracking via \`$DEFAULT_LOG\`."
  fi
  exit 0
fi

# Parse entries, skipping malformed lines with a warning to stderr.
TMP_VALID="$(mktemp)"
trap 'rm -f "$TMP_VALID"' EXIT

LINE_NUM=0
SKIPPED=0
while IFS= read -r line || [[ -n "$line" ]]; do
  LINE_NUM=$((LINE_NUM + 1))
  [[ -z "$line" ]] && continue
  if ! echo "$line" | jq -e 'type == "object"' >/dev/null 2>&1; then
    echo "WARNING: skipping malformed line $LINE_NUM" >&2
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  # Require the essential numeric fields to be present and > 0
  if ! echo "$line" | jq -e '.category and .human_estimate_days and .agent_wallclock_hours_actual and (.agent_wallclock_hours_actual > 0)' >/dev/null 2>&1; then
    echo "WARNING: skipping incomplete line $LINE_NUM" >&2
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  echo "$line" >> "$TMP_VALID"
done < "$LOG_PATH"

TOTAL=$(wc -l < "$TMP_VALID" | tr -d ' ')

if [[ "$TOTAL" -eq 0 ]]; then
  if [[ "$FORMAT" == "json" ]]; then
    printf '{"samples":0,"message":"No valid samples. Log exists but contains no parseable entries."}\n'
  else
    echo "No samples yet. Start tracking via \`$DEFAULT_LOG\`."
  fi
  exit 0
fi

# Defaults from dual-estimation.md
default_for() {
  case "$1" in
    trivial)  echo "15" ;;
    standard) echo "10" ;;
    complex)  echo "7"  ;;
    novel)    echo "5"  ;;
    legacy)   echo "2"  ;;
    *)        echo "10" ;;
  esac
}

# Compute per-category empirical speedup. Speedup is
# (human_hours_total / agent_hours_total), where human_hours = human_days * 8.
compute_category() {
  local cat="$1"
  jq -s --arg cat "$cat" '
    map(select(.category == $cat))
    | { count: length,
        human_hours: (map(.human_estimate_days * 8) | add // 0),
        agent_hours: (map(.agent_wallclock_hours_actual) | add // 0) }
    | .speedup = (if .agent_hours > 0 then (.human_hours / .agent_hours) else 0 end)
  ' "$TMP_VALID"
}

CATS=(trivial standard complex novel legacy)

# Build JSON summary
SUMMARY_JSON=$(jq -n '{samples: 0, categories: {}, global_speedup: 0}')
SUMMARY_JSON=$(echo "$SUMMARY_JSON" | jq --argjson total "$TOTAL" '.samples = $total')

TOTAL_HUMAN_H=0
TOTAL_AGENT_H=0
for cat in "${CATS[@]}"; do
  CAT_JSON=$(compute_category "$cat")
  COUNT=$(echo "$CAT_JSON" | jq -r '.count')
  SPEEDUP=$(echo "$CAT_JSON" | jq -r '.speedup')
  HUMAN_H=$(echo "$CAT_JSON" | jq -r '.human_hours')
  AGENT_H=$(echo "$CAT_JSON" | jq -r '.agent_hours')
  DEFAULT=$(default_for "$cat")

  # Only suggest if samples >= MIN_SAMPLES; else "insufficient data"
  SUGGESTION="insufficient data"
  if [[ "$COUNT" -ge "$MIN_SAMPLES" ]]; then
    # Compare speedup vs default. Close if within 30%.
    RATIO=$(awk -v s="$SPEEDUP" -v d="$DEFAULT" 'BEGIN { if (d==0) print 0; else printf "%.2f", s/d }')
    CLOSE=$(awk -v r="$RATIO" 'BEGIN { if (r >= 0.7 && r <= 1.3) print "yes"; else print "no" }')
    if [[ "$CLOSE" == "yes" ]]; then
      SUGGESTION="close enough"
    else
      SUGGESTION=$(awk -v r="$RATIO" 'BEGIN { printf "suggest x%.2f", r }')
    fi
  elif [[ "$COUNT" -gt 0 ]]; then
    SUGGESTION="need $MIN_SAMPLES samples (have $COUNT)"
  fi

  SUMMARY_JSON=$(echo "$SUMMARY_JSON" | jq \
    --arg cat "$cat" \
    --argjson count "$COUNT" \
    --argjson speedup "$SPEEDUP" \
    --argjson default "$DEFAULT" \
    --arg suggestion "$SUGGESTION" \
    '.categories[$cat] = {count: $count, speedup: $speedup, default: $default, suggestion: $suggestion}')

  TOTAL_HUMAN_H=$(awk -v a="$TOTAL_HUMAN_H" -v b="$HUMAN_H" 'BEGIN { printf "%.4f", a + b }')
  TOTAL_AGENT_H=$(awk -v a="$TOTAL_AGENT_H" -v b="$AGENT_H" 'BEGIN { printf "%.4f", a + b }')
done

GLOBAL=$(awk -v h="$TOTAL_HUMAN_H" -v a="$TOTAL_AGENT_H" 'BEGIN { if (a==0) print "0"; else printf "%.2f", h/a }')
SUMMARY_JSON=$(echo "$SUMMARY_JSON" | jq --argjson g "$GLOBAL" '.global_speedup = $g')

# Recommendation text
GLOBAL_RATIO=$(awk -v g="$GLOBAL" 'BEGIN { printf "%.2f", g/10 }')
CLOSE_TO_10=$(awk -v g="$GLOBAL" 'BEGIN { if (g >= 7 && g <= 13) print "yes"; else print "no" }')
if [[ "$CLOSE_TO_10" == "yes" ]]; then
  RECOMMENDATION="keep 10x headline (within 30% of empirical)"
else
  RECOMMENDATION="consider updating table; empirical diverges from defaults"
fi
SUMMARY_JSON=$(echo "$SUMMARY_JSON" | jq --arg r "$RECOMMENDATION" '.recommendation = $r')

if [[ "$FORMAT" == "json" ]]; then
  echo "$SUMMARY_JSON"
  exit 0
fi

# Banner output
echo "Dual Estimation Calibration Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
COUNTS=()
for cat in "${CATS[@]}"; do
  c=$(echo "$SUMMARY_JSON" | jq -r ".categories.$cat.count")
  COUNTS+=("$cat: $c")
done
printf "Samples: %s (%s)\n" "$TOTAL" "$(IFS=,; echo "${COUNTS[*]}")"
if [[ "$SKIPPED" -gt 0 ]]; then
  printf "Skipped: %s malformed or incomplete line(s)\n" "$SKIPPED"
fi
echo ""
echo "Empirical speedup by category:"
for cat in "${CATS[@]}"; do
  c=$(echo "$SUMMARY_JSON" | jq -r ".categories.$cat.count")
  if [[ "$c" == "0" ]]; then
    printf "  %-9s —     (insufficient data)\n" "${cat}:"
    continue
  fi
  s=$(echo "$SUMMARY_JSON" | jq -r ".categories.$cat.speedup")
  d=$(echo "$SUMMARY_JSON" | jq -r ".categories.$cat.default")
  sg=$(echo "$SUMMARY_JSON" | jq -r ".categories.$cat.suggestion")
  s_fmt=$(awk -v x="$s" 'BEGIN { printf "%.1f", x }')
  printf "  %-9s %sx  (default %sx)  → %s\n" "${cat}:" "$s_fmt" "$d" "$sg"
done
echo ""
printf "Global pipeline speedup (weighted): %sx\n" "$GLOBAL"
printf "Recommendation: %s\n" "$RECOMMENDATION"
