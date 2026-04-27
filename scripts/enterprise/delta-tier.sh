#!/usr/bin/env bash
set -uo pipefail
# delta-tier.sh — SPEC-SE-035 helper
#
# Computes the green/amber/red tier from declared vs computed numeric values.
# Reusable from any pm-workspace command that wants to render a drift indicator
# (sprint-status, portfolio-overview, client-health, billing dashboards, etc.)
#
# Usage:
#   bash scripts/enterprise/delta-tier.sh <declared> <computed> [amber] [red]
#   bash scripts/enterprise/delta-tier.sh --json <declared> <computed> [amber] [red]
#   bash scripts/enterprise/delta-tier.sh --color <declared> <computed> [amber] [red]
#
# Defaults: amber=1000, red=5000 (override per dimension).
#
# Exit codes: 0 ok | 2 usage error | 3 invalid number
#
# Reference: SPEC-SE-035 (docs/propuestas/savia-enterprise/SPEC-SE-035-reconciliation-delta-engine.md)
# Reference: dreamxist/balance supabase/migrations/00009_reconciliation.sql (pattern source, MIT)

MODE="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)  MODE="json";  shift ;;
    --color) MODE="color"; shift ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) break ;;
  esac
done

[[ $# -lt 2 || $# -gt 4 ]] && {
  echo "Usage: delta-tier.sh [--json|--color] <declared> <computed> [amber=1000] [red=5000]" >&2
  exit 2
}

DECLARED="$1"
COMPUTED="$2"
AMBER="${3:-1000}"
RED="${4:-5000}"

is_number() { [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; }

for n in "$DECLARED" "$COMPUTED" "$AMBER" "$RED"; do
  if ! is_number "$n"; then
    echo "ERROR: '$n' is not a number" >&2
    exit 3
  fi
done

# Use awk for robust float arithmetic (bash builtin is integer-only)
DELTA=$(awk -v a="$DECLARED" -v b="$COMPUTED" 'BEGIN { printf "%.4f", a - b }')
ABS_DELTA=$(awk -v d="$DELTA" 'BEGIN { d = (d < 0) ? -d : d; printf "%.4f", d }')

TIER=$(awk -v abs="$ABS_DELTA" -v amber="$AMBER" -v red="$RED" 'BEGIN {
  if (abs >= red)        print "red"
  else if (abs >= amber) print "amber"
  else                   print "green"
}')

case "$MODE" in
  text)
    printf 'declared=%s computed=%s delta=%s tier=%s\n' "$DECLARED" "$COMPUTED" "$DELTA" "$TIER"
    ;;
  json)
    printf '{"declared":%s,"computed":%s,"delta":%s,"abs_delta":%s,"tier":"%s","amber":%s,"red":%s}\n' \
      "$DECLARED" "$COMPUTED" "$DELTA" "$ABS_DELTA" "$TIER" "$AMBER" "$RED"
    ;;
  color)
    case "$TIER" in
      green) printf '\033[32m●\033[0m green   delta=%s\n' "$DELTA" ;;
      amber) printf '\033[33m●\033[0m amber   delta=%s\n' "$DELTA" ;;
      red)   printf '\033[31m●\033[0m red     delta=%s\n' "$DELTA" ;;
    esac
    ;;
esac
