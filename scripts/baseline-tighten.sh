#!/usr/bin/env bash
# baseline-tighten.sh — SE-046 Slice 1 baseline auto-tighten.
#
# Previene baselines inflados (ratchet inerte): tras cada bench run,
# si la medida actual es MENOR que el baseline, actualiza el baseline
# a `current`. Nunca lo afloja.
#
# Uso principal: .ci-baseline/hook-critical-violations.count (inflado en 10,
# real 4).
#
# Usage:
#   baseline-tighten.sh --baseline FILE --current N
#   baseline-tighten.sh --baseline FILE --current N --dry-run
#   baseline-tighten.sh --baseline FILE --current N --json
#
# Exit codes:
#   0 — baseline tightened (or already tight)
#   1 — current > baseline (should fail somewhere else, NOT here)
#   2 — usage error
#
# Ref: SE-046, audit-arquitectura-20260420.md D6
# Safety: solo escribe en el baseline file indicado. set -uo pipefail.

set -uo pipefail

BASELINE=""
CURRENT=""
DRY_RUN=0
JSON=0

usage() {
  cat <<EOF
Usage:
  $0 --baseline FILE --current N [options]

Required:
  --baseline FILE    Path to baseline file (e.g. .ci-baseline/hook-critical-violations.count)
  --current N        Current measured value (integer)

Optional:
  --dry-run          Don't write, just report
  --json             JSON output

Aprieta (nunca afloja) baseline. Solo re-escribe si current < baseline.
Ref: SE-046 §Objective.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --baseline) BASELINE="$2"; shift 2 ;;
    --current) CURRENT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$BASELINE" ]] && { echo "ERROR: --baseline required" >&2; exit 2; }
[[ -z "$CURRENT" ]] && { echo "ERROR: --current required" >&2; exit 2; }

if ! [[ "$CURRENT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --current must be non-negative integer" >&2; exit 2
fi

# Read existing baseline (0 if missing)
PREVIOUS=0
if [[ -f "$BASELINE" ]]; then
  PREVIOUS=$(cat "$BASELINE" 2>/dev/null | tr -dc '0-9')
  PREVIOUS="${PREVIOUS:-0}"
fi

# Decision
ACTION="noop"
EXIT_CODE=0

if [[ "$CURRENT" -gt "$PREVIOUS" ]]; then
  # Regressión detectada — este script NO la enmascara
  ACTION="regression"
  EXIT_CODE=1
elif [[ "$CURRENT" -lt "$PREVIOUS" ]]; then
  # Mejora — apretar baseline
  ACTION="tighten"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$(dirname "$BASELINE")"
    echo "$CURRENT" > "$BASELINE"
  fi
else
  ACTION="noop"  # current == previous
fi

if [[ "$JSON" -eq 1 ]]; then
  cat <<JSON
{"action":"$ACTION","baseline_file":"$BASELINE","previous":$PREVIOUS,"current":$CURRENT,"dry_run":$DRY_RUN}
JSON
else
  echo "=== SE-046 Baseline Tighten ==="
  echo ""
  echo "Baseline file:  $BASELINE"
  echo "Previous:       $PREVIOUS"
  echo "Current:        $CURRENT"
  echo "Action:         $ACTION"
  if [[ "$ACTION" == "tighten" && "$DRY_RUN" -eq 0 ]]; then
    echo "Status:         ✅ baseline tightened $PREVIOUS → $CURRENT"
  elif [[ "$ACTION" == "tighten" && "$DRY_RUN" -eq 1 ]]; then
    echo "Status:         (dry-run) would tighten $PREVIOUS → $CURRENT"
  elif [[ "$ACTION" == "regression" ]]; then
    echo "Status:         ❌ regression detected. current ($CURRENT) > baseline ($PREVIOUS)"
    echo "                This script does NOT relax baselines. Fix the regression."
  else
    echo "Status:         baseline unchanged"
  fi
fi

exit $EXIT_CODE
