#!/usr/bin/env bash
# validate-handoff.sh — Validate handoff structure with termination_reason
# SPEC-TERMINAL-STATE-HANDOFF: enforce enum of valid termination reasons
# Ref: docs/specs/SPEC-TERMINAL-STATE-HANDOFF.spec.md
#
# Usage: bash scripts/validate-handoff.sh [--file FILE]
#        cat handoff.yaml | bash scripts/validate-handoff.sh
#
# Exit codes:
#   0 = valid
#   1 = warning (field missing, not blocking)
#   2 = invalid (enum value out of range or fatal error)

set -uo pipefail

VALID_REASONS=(
  "completed"
  "user_abort"
  "token_budget"
  "stop_hook"
  "max_turns"
  "unrecoverable_error"
)

INPUT_FILE=""
INPUT=""

show_help() {
  sed -n '2,12p' "$0" | sed 's/^# \?//'
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)
        [[ $# -lt 2 ]] && { echo "Error: --file requires a path" >&2; exit 2; }
        INPUT_FILE="$2"; shift 2 ;;
      --help|-h)
        show_help
        exit 0 ;;
      *)
        echo "Error: unknown option $1" >&2
        exit 2 ;;
    esac
  done
}

read_input() {
  if [[ -n "$INPUT_FILE" ]]; then
    if [[ ! -f "$INPUT_FILE" ]]; then
      echo "Error: file not found: $INPUT_FILE" >&2
      exit 2
    fi
    INPUT=$(cat "$INPUT_FILE")
  else
    if [[ -t 0 ]]; then
      echo "Error: no input provided (stdin empty and no --file)" >&2
      exit 2
    fi
    INPUT=$(cat)
  fi
  [[ -z "$INPUT" ]] && { echo "Error: empty input" >&2; exit 2; }
}

extract_termination_reason() {
  # Match: termination_reason: "value" or termination_reason: value
  echo "$INPUT" | grep -E '^[[:space:]]*termination_reason[[:space:]]*:' \
    | head -1 \
    | sed -E 's/^[[:space:]]*termination_reason[[:space:]]*:[[:space:]]*//' \
    | tr -d '"' \
    | tr -d "'" \
    | awk '{print $1}'
}

validate_enum() {
  local value="$1"
  for valid in "${VALID_REASONS[@]}"; do
    [[ "$value" == "$valid" ]] && return 0
  done
  return 1
}

main() {
  parse_args "$@"
  read_input

  local reason
  reason=$(extract_termination_reason)

  if [[ -z "$reason" ]]; then
    echo "WARNING: termination_reason field missing from handoff" >&2
    echo "  Expected enum: ${VALID_REASONS[*]}" >&2
    exit 1
  fi

  if validate_enum "$reason"; then
    echo "VALID: termination_reason=$reason"
    exit 0
  fi

  echo "INVALID: termination_reason=$reason not in enum" >&2
  echo "  Valid values: ${VALID_REASONS[*]}" >&2
  exit 2
}

main "$@"
