#!/usr/bin/env bash
# ── context-budget-check.sh ──────────────────────────────────────────────────
# Proactive context budget tracker with dual threshold and circuit breaker.
# Checks context usage BEFORE operations, not after.
#
# Usage:
#   context-budget-check.sh [percentage]
#   CLAUDE_CONTEXT_USAGE_PCT=82 context-budget-check.sh
#
# Output (stdout): NO_ACTION | STANDARD_COMPACT | EMERGENCY_COMPACT | CIRCUIT_OPEN
# Exit codes: 0 = no action, 1 = compact needed, 2 = emergency, 3 = circuit open
# ──────────────────────────────────────────────────────────────────────────────

set -uo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
THRESHOLD_STANDARD="${CONTEXT_BUDGET_THRESHOLD_STANDARD:-80}"
THRESHOLD_EMERGENCY="${CONTEXT_BUDGET_THRESHOLD_EMERGENCY:-95}"
MAX_CONSECUTIVE_FAILURES="${CONTEXT_BUDGET_MAX_FAILURES:-3}"
FAILURE_FILE="${HOME}/.savia/compact-failures"

# ── Read context percentage ──────────────────────────────────────────────────

get_context_pct() {
  # Priority: argument > env var > default 0
  if [[ -n "${1:-}" ]]; then
    echo "$1"
  elif [[ -n "${CLAUDE_CONTEXT_USAGE_PCT:-}" ]]; then
    echo "$CLAUDE_CONTEXT_USAGE_PCT"
  else
    echo "0"
  fi
}

# ── Circuit breaker ──────────────────────────────────────────────────────────

ensure_dir() {
  local dir
  dir="$(dirname "$FAILURE_FILE")"
  [[ -d "$dir" ]] || mkdir -p "$dir"
}

get_failure_count() {
  if [[ -f "$FAILURE_FILE" ]]; then
    cat "$FAILURE_FILE" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

increment_failures() {
  ensure_dir
  local count
  count=$(get_failure_count)
  echo "$(( count + 1 ))" > "$FAILURE_FILE"
}

reset_failures() {
  if [[ -f "$FAILURE_FILE" ]]; then
    rm -f "$FAILURE_FILE"
  fi
}

# ── Main logic ───────────────────────────────────────────────────────────────

main() {
  local pct
  pct=$(get_context_pct "${1:-}")

  # Validate: must be a non-negative integer
  if ! [[ "$pct" =~ ^[0-9]+$ ]]; then
    echo "NO_ACTION"
    exit 0
  fi

  local failures
  failures=$(get_failure_count)

  # Below standard threshold: reset failures, no action needed
  if [[ "$pct" -lt "$THRESHOLD_STANDARD" ]]; then
    reset_failures
    echo "NO_ACTION"
    exit 0
  fi

  # Check circuit breaker before recommending another compact
  if [[ "$failures" -ge "$MAX_CONSECUTIVE_FAILURES" ]]; then
    echo "CIRCUIT_OPEN"
    exit 3
  fi

  # Emergency threshold (>= 95%)
  if [[ "$pct" -ge "$THRESHOLD_EMERGENCY" ]]; then
    increment_failures
    echo "EMERGENCY_COMPACT"
    exit 2
  fi

  # Standard threshold (>= 80%)
  increment_failures
  echo "STANDARD_COMPACT"
  exit 1
}

main "$@"
