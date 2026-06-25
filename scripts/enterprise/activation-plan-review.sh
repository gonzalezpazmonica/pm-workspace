#!/usr/bin/env bash
# activation-plan-review.sh — SE-034 Agent Activation Plan
set -uo pipefail
# Displays and validates a daily activation plan for PM review.
#
# Usage:
#   scripts/enterprise/activation-plan-review.sh [--date YYYY-MM-DD] [--approve|--reject]
#
# Reads:  output/activation-plans/{date}.md
# Output: approved (exit 0) or rejected (exit 1) with reason

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

PLAN_DATE="$(date +%Y-%m-%d)"
ACTION=""  # approve | reject | review (default)

# ── arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)    PLAN_DATE="$2"; shift 2 ;;
    --approve) ACTION="approve"; shift ;;
    --reject)  ACTION="reject"; shift ;;
    --help|-h)
      echo "Usage: activation-plan-review.sh [--date YYYY-MM-DD] [--approve|--reject]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

PLAN_FILE="${REPO_ROOT}/output/activation-plans/${PLAN_DATE}.md"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "ERROR: Plan not found: ${PLAN_FILE}" >&2
  echo "       Run daily-activation-plan.sh first." >&2
  exit 3
fi

# ── validate plan structure ───────────────────────────────────────────────────
_validate_plan() {
  local errors=0

  if ! grep -q '## Token Budget' "$PLAN_FILE"; then
    echo "WARN: Missing 'Token Budget' section" >&2
    (( errors++ ))
  fi
  if ! grep -q '## Priority Queue' "$PLAN_FILE" && ! grep -q '## Recommended Agent Sequence' "$PLAN_FILE"; then
    echo "WARN: Missing agent sequence section" >&2
    (( errors++ ))
  fi

  return $errors
}

# ── display plan ──────────────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════════"
echo "  Activation Plan: ${PLAN_DATE}"
echo "══════════════════════════════════════════════════════════"
cat "$PLAN_FILE"
echo ""
echo "══════════════════════════════════════════════════════════"

# ── validate ──────────────────────────────────────────────────────────────────
validation_errors=0
_validate_plan || validation_errors=$?

if [[ "$ACTION" == "approve" ]]; then
  if (( validation_errors > 0 )); then
    echo "Plan has ${validation_errors} validation warning(s). Approved with warnings."
  else
    echo "Plan APPROVED for ${PLAN_DATE}."
  fi
  exit 0

elif [[ "$ACTION" == "reject" ]]; then
  echo "Plan REJECTED for ${PLAN_DATE}."
  exit 1

else
  # Interactive review mode
  if [[ -t 0 ]]; then
    echo ""
    printf 'Approve this plan? [y/N]: '
    read -r answer
    case "$answer" in
      [Yy]|[Yy][Ee][Ss])
        echo "Plan APPROVED."
        exit 0 ;;
      *)
        echo "Plan REJECTED or not confirmed."
        exit 1 ;;
    esac
  else
    # Non-interactive: just display and exit 0
    echo ""
    echo "Plan displayed. Run with --approve or --reject to set status."
    exit 0
  fi
fi
