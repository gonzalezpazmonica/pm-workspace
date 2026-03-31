#!/usr/bin/env bash
# execution-supervisor.sh — Advisory reflection trigger (SPEC-065)
# Called after failed actions. Displays reflection prompt at attempt 3+.
# ALWAYS exits 0 — advisory, never blocking.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:-unknown}"
TARGET="${2:-unknown}"
DETAIL="${3:-no detail}"

# Get attempt count from session action log
ATTEMPTS=$(bash "$SCRIPT_DIR/session-action-log.sh" attempts "$ACTION" "$TARGET" 2>/dev/null || echo 0)

# Attempt 1-2: silent
if [[ "$ATTEMPTS" -lt 3 ]]; then
  exit 0
fi

# Attempt 3+: reflection prompt
{
  echo ""
  echo "================================================================"
  echo "  SUPERVISOR: attempt #${ATTEMPTS} failed on [$ACTION] -> [$TARGET]"
  echo "================================================================"
  echo ""
  echo "  Previous failures:"

  # Read failure details from log
  local_details=$(bash "$SCRIPT_DIR/session-action-log.sh" details "$ACTION" "$TARGET" 2>/dev/null || true)
  idx=1
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "    ${idx}. $line"
    idx=$((idx + 1))
  done <<< "$local_details"
  echo ""

  echo "  STOP. Before attempting again:"
  echo "  1. What is the ROOT CAUSE pattern across all $ATTEMPTS failures?"
  echo "  2. Are you patching symptoms or fixing the cause?"
  echo "  3. What would a senior engineer do differently?"
  echo ""

  if [[ "$ATTEMPTS" -ge 4 ]]; then
    echo "  ESCALATION (attempt $ATTEMPTS):"
    echo "  - Is this the right approach entirely?"
    echo "  - Should you redesign instead of retry?"
    echo "  - Consider writing an analysis file before proceeding."
    echo ""
  fi

  echo "  Write your analysis before proceeding."
  echo "================================================================"
  echo ""
} >&2

# Advisory only — never block
exit 0
