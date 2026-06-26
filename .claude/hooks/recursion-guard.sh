#!/usr/bin/env bash
# .opencode/hooks/recursion-guard.sh — PreToolUse hook
# Blocks autonomous loop launch when already inside a running loop.
# Ref: SPEC-RECURSION-GUARD, docs/rules/domain/autonomous-safety.md
#
# Exit codes:
#   0 — allow (no loop context, or tool is not a loop)
#   2 — block (recursive loop detected)
#
# Environment:
#   SAVIA_LOOP_CONTEXT  format: "loop_name:depth"  e.g. "overnight-sprint:1"
#   OPENCODE_TOOL_INPUT  JSON string of the current tool call input

set -uo pipefail

# Loop pattern list
LOOP_PATTERNS=(
  "overnight-sprint"
  "code-improvement-loop"
  "tech-research-agent"
  "loop_skill"
)

_detect_loop() {
  local input="${1:-}"
  for pattern in "${LOOP_PATTERNS[@]}"; do
    if printf '%s' "$input" | grep -qF "$pattern"; then
      printf '%s' "$pattern"
      return 0
    fi
  done
  return 1
}

main() {
  # No loop context — always allow
  if [[ -z "${SAVIA_LOOP_CONTEXT:-}" ]]; then
    exit 0
  fi

  local tool_input="${OPENCODE_TOOL_INPUT:-}"

  local detected_loop
  if ! detected_loop="$(_detect_loop "$tool_input")"; then
    exit 0
  fi

  printf 'BLOCKED [recursion-guard]: Loop recursion detected.\n'
  printf '  Current context: %s\n' "${SAVIA_LOOP_CONTEXT}"
  printf "  Cannot launch '%s' from inside a running loop.\n" "${detected_loop}"
  printf "  To run nested loops, use 'SAVIA_LOOP_CONTEXT=' to clear (autonomous-safety Rule applies).\n"
  exit 2
}

main "$@"
