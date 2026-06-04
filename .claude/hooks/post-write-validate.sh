#!/usr/bin/env bash
# post-write-validate.sh — SPEC-184 write-time non-blocking validators
#
# PostToolUse hook for Edit|Write on *.md. Runs composable validators that
# warn to stderr (never block). Agent reads warnings same turn and self-repairs.
#
# Always exits 0. Toggle via SAVIA_WRITE_VALIDATORS_ENABLED=false.
#
# Reference: docs/propuestas/SPEC-184-writetime-validator-nonblocking.md
# Reference: docs/rules/domain/write-time-validation.md

set -uo pipefail

# Global toggle
if [[ "${SAVIA_WRITE_VALIDATORS_ENABLED:-true}" == "false" ]]; then
  exit 0
fi

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$FILE_PATH" ]] && exit 0
[[ -f "$FILE_PATH" ]] || exit 0

# Only markdown files
[[ "$FILE_PATH" == *.md ]] || exit 0

# Bypass dirs (path-substring match)
for skip in "/output/" "/.git/" "/node_modules/" "/dist/" "/raw/"; do
  case "$FILE_PATH" in
    *"$skip"*) exit 0 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)"
VALIDATORS_DIR="$ROOT/.opencode/hooks/validators"

# Run each validator with the file path. Each is exit-0-always; their stderr
# bubbles up to the agent's view. Failures in a validator must not block.
if [[ -d "$VALIDATORS_DIR" ]]; then
  for v in "$VALIDATORS_DIR"/validate-*.sh; do
    [[ -x "$v" ]] || continue
    bash "$v" "$FILE_PATH" 2>&1 1>/dev/null || true
  done
fi

exit 0
