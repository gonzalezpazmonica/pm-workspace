#!/usr/bin/env bash
# estimate-convert.sh — Convert human-days to agent-hours using dual ratios
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-013-dual-estimation.md
#
# Usage:
#   estimate-convert.sh <human_days> [options]
#
# Options:
#   --mode conservative|empirical   default: conservative (10x fixed)
#   --category trivial|standard|complex|novel|legacy  default: standard
#   --format banner|json            default: banner
#   --min-samples N                 min samples to honor --mode empirical (default 10)
#
# Exit codes:
#   0  success
#   1  usage error
#   2  empirical requested but insufficient data → fell back to conservative
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ACTUALS_LOG="${AGENT_ACTUALS_LOG:-$REPO_ROOT/data/agent-actuals.jsonl}"
EXAMPLE_LOG="$REPO_ROOT/data/agent-actuals.example.jsonl"
MIN_SAMPLES="${DUAL_ESTIMATION_MIN_SAMPLES:-10}"

HUMAN_DAYS=""
MODE="conservative"
CATEGORY="standard"
FORMAT="banner"
FELL_BACK=0

# Category multipliers (agent_hours = human_days × base × category_factor)
# Base (conservative): 0.8 (= 8h / 10x)
# Category factors adjust the speedup:
#   trivial  15x → factor 0.533
#   standard 10x → factor 0.8
#   complex  7x  → factor 1.143
#   novel    5x  → factor 1.6
#   legacy   2x  → factor 4.0
category_factor() {
  case "$1" in
    trivial)  echo "0.533" ;;
    standard) echo "0.8" ;;
    complex)  echo "1.143" ;;
    novel)    echo "1.6" ;;
    legacy)   echo "4.0" ;;
    *) echo "" ;;
  esac
}

usage() {
  sed -n '3,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 1
}

# Parse args
[[ $# -lt 1 ]] && usage
HUMAN_DAYS="$1"; shift
if ! [[ "$HUMAN_DAYS" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "estimate-convert: human_days must be a positive number, got: $HUMAN_DAYS" >&2
  usage
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    --category) CATEGORY="${2:-}"; shift 2 ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --min-samples) MIN_SAMPLES="${2:-10}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "estimate-convert: unknown flag: $1" >&2; usage ;;
  esac
done

[[ -z "$(category_factor "$CATEGORY")" ]] && { echo "estimate-convert: invalid category: $CATEGORY" >&2; exit 1; }
[[ "$MODE" != "conservative" && "$MODE" != "empirical" ]] && { echo "estimate-convert: invalid mode: $MODE" >&2; exit 1; }

# Resolve effective log file (fall back to example if live log missing)
LOG_FILE="$ACTUALS_LOG"
[[ ! -f "$LOG_FILE" && -f "$EXAMPLE_LOG" ]] && LOG_FILE="$EXAMPLE_LOG"

# Compute empirical global speedup if needed
EMPIRICAL_SPEEDUP=""
SAMPLE_COUNT=0
if [[ -f "$LOG_FILE" ]] && command -v jq >/dev/null 2>&1; then
  SAMPLE_COUNT=$(grep -c '^{' "$LOG_FILE" 2>/dev/null || echo 0)
  if [[ "$SAMPLE_COUNT" -gt 0 ]]; then
    EMPIRICAL_SPEEDUP=$(jq -s '
      [.[] | select(.agent_wallclock_hours_actual != null and .human_estimate_days != null)]
      | if length == 0 then empty
        else (map(.human_estimate_days * 8) | add) / (map(.agent_wallclock_hours_actual) | add)
        end
    ' "$LOG_FILE" 2>/dev/null || echo "")
  fi
fi

# Decide ratio
if [[ "$MODE" == "empirical" ]]; then
  if [[ -z "$EMPIRICAL_SPEEDUP" ]] || [[ "$SAMPLE_COUNT" -lt "$MIN_SAMPLES" ]]; then
    FELL_BACK=1
    MODE="conservative"
  fi
fi

# Compute agent hours
CAT_FACTOR=$(category_factor "$CATEGORY")
if [[ "$MODE" == "conservative" ]]; then
  SPEEDUP_USED="10"
  AGENT_HOURS=$(awk -v d="$HUMAN_DAYS" -v f="$CAT_FACTOR" 'BEGIN { printf "%.2f", d * f }')
else
  SPEEDUP_USED="$EMPIRICAL_SPEEDUP"
  # base = 8h / empirical_speedup, then × category factor relative to 0.8
  AGENT_HOURS=$(awk -v d="$HUMAN_DAYS" -v s="$EMPIRICAL_SPEEDUP" -v f="$CAT_FACTOR" \
    'BEGIN { printf "%.2f", d * (8 / s) * (f / 0.8) }')
fi

# Output
if [[ "$FORMAT" == "json" ]]; then
  printf '{"human_days":%s,"category":"%s","mode":"%s","speedup_used":%s,"agent_hours":%s,"sample_count":%s,"fell_back":%s}\n' \
    "$HUMAN_DAYS" "$CATEGORY" "$MODE" "$SPEEDUP_USED" "$AGENT_HOURS" "$SAMPLE_COUNT" "$FELL_BACK"
else
  echo "Dual Estimation Conversion"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  Human estimate:  %s days (%s hours)\n" "$HUMAN_DAYS" "$(awk -v d="$HUMAN_DAYS" 'BEGIN { printf "%.1f", d*8 }')"
  printf "  Category:        %s\n" "$CATEGORY"
  printf "  Mode:            %s" "$MODE"
  [[ "$FELL_BACK" -eq 1 ]] && printf " (empirical requested but <%s samples, fell back)" "$MIN_SAMPLES"
  printf "\n"
  printf "  Speedup used:    %sx\n" "$SPEEDUP_USED"
  printf "  Agent estimate:  %s hours\n" "$AGENT_HOURS"
  [[ "$SAMPLE_COUNT" -gt 0 ]] && printf "  Sample pool:     %s entries\n" "$SAMPLE_COUNT"
fi

[[ "$FELL_BACK" -eq 1 ]] && exit 2
exit 0
