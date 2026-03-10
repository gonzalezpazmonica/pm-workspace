#!/usr/bin/env bash
set -uo pipefail
# adb-run.sh — Execute adb-wrapper functions without compound && chains
#
# Usage:
#   ./scripts/adb-run.sh adb_auto_select
#   ./scripts/adb-run.sh adb_auto_select adb_screenshot /tmp/screen.png
#   ./scripts/adb-run.sh adb_auto_select "adb_tap 500 900" "adb_screenshot /tmp/after.png"
#   ./scripts/adb-run.sh --logcat-errors 30 com.savia.mobile
#
# Why this exists:
#   Claude Code is shell-aware and treats && || ; as command boundaries.
#   Permission patterns like Bash(source wrapper.sh && *) don't cover
#   multi-step chains. This script wraps everything into a single command
#   that needs only one permission pattern: Bash(./scripts/adb-run.sh *)
#
# Each argument is one adb-wrapper function call (with its args).
# Use quotes for calls with arguments: "adb_tap 500 900"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="$SCRIPT_DIR/lib/adb-wrapper.sh"

if [[ ! -f "$WRAPPER" ]]; then
  echo "ERROR: adb-wrapper.sh not found at $WRAPPER" >&2
  exit 1
fi

# shellcheck source=lib/adb-wrapper.sh
source "$WRAPPER"

# Special flags
case "${1:-}" in
  -h|--help)
    echo "Usage: ./scripts/adb-run.sh <func> [<func> ...]"
    echo ""
    echo "Execute one or more adb-wrapper functions sequentially."
    echo "Each argument is a function call (quote args with spaces)."
    echo ""
    echo "Examples:"
    echo "  ./scripts/adb-run.sh adb_auto_select adb_devices"
    echo "  ./scripts/adb-run.sh adb_auto_select \"adb_screenshot /tmp/s.png\""
    echo "  ./scripts/adb-run.sh adb_auto_select \"adb_tap 500 900\" \"adb_screenshot /tmp/after.png\""
    echo "  ./scripts/adb-run.sh adb_auto_select adb_logcat_clear \"adb_launch com.savia.mobile\""
    exit 0
    ;;
  "")
    echo "ERROR: No commands specified. Use --help for usage." >&2
    exit 1
    ;;
esac

# Execute each argument as a function call
FAILED=0
for cmd in "$@"; do
  # Split the command string into function name and arguments
  # shellcheck disable=SC2086
  if ! eval "$cmd"; then
    echo "FAILED: $cmd" >&2
    FAILED=$((FAILED + 1))
  fi
done

if [[ $FAILED -gt 0 ]]; then
  echo "$FAILED command(s) failed" >&2
  exit 1
fi
