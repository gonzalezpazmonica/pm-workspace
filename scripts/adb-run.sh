#!/usr/bin/env bash
set -uo pipefail
# adb-run.sh — Execute adb-wrapper functions without compound && chains
#
# Usage:
#   ./scripts/adb-run.sh adb_auto_select
#   ./scripts/adb-run.sh adb_auto_select "adb_screenshot /tmp/screen.png"
#   ./scripts/adb-run.sh adb_auto_select "adb_tap 500 900" "adb_screenshot /tmp/after.png"
#   ./scripts/adb-run.sh adb_auto_select "adb_tap_text 'Conectar ahora'"
#
# Why this exists:
#   Claude Code is shell-aware and treats && || ; as command boundaries.
#   Permission patterns like Bash(source wrapper.sh && *) don't cover
#   multi-step chains. This script wraps everything into a single command
#   that needs only one permission pattern: Bash(./scripts/adb-run.sh *)
#
# Each argument is one adb-wrapper function call (with its args).
# Use quotes for calls with arguments: "adb_tap 500 900". Inside a call,
# single or double quotes group words: "adb_tap_text 'Conectar ahora'".
#
# Safety: arguments are NOT evaluated by the shell. Each one is split into
# words (quotes honoured; no expansion, no ; | & or $(...)) and must start
# with a public adb_* function of the wrapper; anything else is REJECTED.
# Without this, the permission Bash(./scripts/adb-run.sh *) would allow any
# shell code.
#
# Exit: 0 if every call succeeded, 1 if any call failed or was rejected.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="$SCRIPT_DIR/lib/adb-wrapper.sh"

if [[ ! -f "$WRAPPER" ]]; then
  echo "ERROR: adb-wrapper.sh not found at $WRAPPER" >&2
  exit 1
fi

# shellcheck source=lib/adb-wrapper.sh
source "$WRAPPER"
# The wrapper enables errexit for interactive sourcing; here each call's exit
# code is collected explicitly, so a failing call must not end the run.
set +e

# Special flags
case "${1:-}" in
  -h|--help)
    echo "Usage: ./scripts/adb-run.sh <func> [<func> ...]"
    echo ""
    echo "Execute one or more adb-wrapper functions sequentially."
    echo "Each argument is a function call (quote args with spaces)."
    echo "Only public adb_* functions are accepted; nothing is shell-evaluated."
    echo ""
    echo "Examples:"
    echo "  ./scripts/adb-run.sh adb_auto_select adb_devices"
    echo "  ./scripts/adb-run.sh adb_auto_select \"adb_screenshot /tmp/s.png\""
    echo "  ./scripts/adb-run.sh adb_auto_select \"adb_tap 500 900\" \"adb_screenshot /tmp/after.png\""
    echo "  ./scripts/adb-run.sh adb_auto_select \"adb_tap_text 'Conectar ahora'\""
    exit 0
    ;;
  "")
    echo "ERROR: No commands specified. Use --help for usage." >&2
    exit 1
    ;;
esac

# Split a call string into WORDS honouring quotes, without any expansion:
# xargs applies shell-like quoting rules but never executes the text.
_split_call() {
  local call="$1" word
  WORDS=()
  if ! printf '%s\n' "$call" | xargs printf '%s\0' >/dev/null 2>&1; then
    echo "REJECTED: cannot parse call (unbalanced quotes?): $call" >&2
    return 1
  fi
  while IFS= read -r -d '' word; do
    WORDS+=("$word")
  done < <(printf '%s\n' "$call" | xargs printf '%s\0')
}

FAILED=0
for cmd in "$@"; do
  if ! _split_call "$cmd"; then
    FAILED=$((FAILED + 1))
    continue
  fi
  fn="${WORDS[0]:-}"
  if [[ ! "$fn" =~ ^adb_[a-z0-9_]+$ ]] || ! declare -F "$fn" >/dev/null; then
    echo "REJECTED: not an adb-wrapper function: $cmd" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  # adb_auto_select runs in this shell so the chosen ADB_DEVICE persists.
  # Every other call runs in a subshell: an abort inside one call (missing
  # argument under set -u, arithmetic error) fails that call only.
  if [[ "$fn" == "adb_auto_select" ]]; then
    "${WORDS[@]}"
  else
    ( "${WORDS[@]}" )
  fi
  rc=$?
  if (( rc != 0 )); then
    echo "FAILED: $cmd" >&2
    FAILED=$((FAILED + 1))
  fi
done

if [[ $FAILED -gt 0 ]]; then
  echo "$FAILED command(s) failed" >&2
  exit 1
fi
