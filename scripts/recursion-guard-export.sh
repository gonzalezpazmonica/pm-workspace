#!/usr/bin/env bash
# scripts/recursion-guard-export.sh — Sets SAVIA_LOOP_CONTEXT for recursion prevention
# Usage: source scripts/recursion-guard-export.sh overnight-sprint
# Ref: SPEC-RECURSION-GUARD

# Guard: this script must be sourced, not executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: recursion-guard-export.sh must be sourced, not executed directly." >&2
  echo "Usage: source scripts/recursion-guard-export.sh <loop-name>" >&2
  exit 1
fi

if [[ -z "${1:-}" ]]; then
  echo "ERROR: recursion-guard-export.sh requires a loop name as first argument" >&2
  return 1  # 'return' because this script is sourced
fi
LOOP_NAME="$1"

CURRENT_DEPTH_RAW=$(printf '%s' "${SAVIA_LOOP_CONTEXT:-:0}" | cut -d: -f2)
if [[ "$CURRENT_DEPTH_RAW" =~ ^[0-9]+$ ]]; then
  CURRENT_DEPTH="$CURRENT_DEPTH_RAW"
else
  CURRENT_DEPTH=0
fi
NEW_DEPTH=$((CURRENT_DEPTH + 1))
export SAVIA_LOOP_CONTEXT="${LOOP_NAME}:${NEW_DEPTH}"
