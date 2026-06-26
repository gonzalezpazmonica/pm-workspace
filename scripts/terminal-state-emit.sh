#!/usr/bin/env bash
# terminal-state-emit.sh — Emits structured termination reason for a loop/agent
# Spec: SPEC-TERMINAL-STATE-HANDOFF
# Ref:  docs/rules/domain/terminal-state-protocol.md
#
# Usage:
#   bash scripts/terminal-state-emit.sh <reason> [--message "detail"] [--loop <name>]
#
# Arguments:
#   <reason>           One of: completed user_abort token_budget stop_hook
#                               max_turns unrecoverable_error
#   --message <text>   Optional human-readable detail string
#   --loop    <name>   Loop/agent name (default: "default")
#
# Output:
#   JSON to stdout
#   Appended to output/loop-state/<loop>/terminal-state.jsonl
#
# Exit codes:
#   0  completed | user_abort
#   1  unknown reason (script error)
#   2  token_budget
#   3  stop_hook
#   4  max_turns
#   5  unrecoverable_error

set -uo pipefail

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# ── Exit code table ───────────────────────────────────────────────────────────

reason_to_exit_code() {
  case "$1" in
    completed)           echo 0 ;;
    user_abort)          echo 0 ;;
    token_budget)        echo 2 ;;
    stop_hook)           echo 3 ;;
    max_turns)           echo 4 ;;
    unrecoverable_error) echo 5 ;;
    *)                   echo 1 ;;
  esac
}

valid_reason() {
  case "$1" in
    completed|user_abort|token_budget|stop_hook|max_turns|unrecoverable_error)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# ── Argument parsing ──────────────────────────────────────────────────────────

REASON=""
MESSAGE=""
LOOP="default"

if [[ $# -eq 0 ]]; then
  usage
fi

REASON="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --message)
      [[ $# -ge 2 ]] || die "--message requires a value"
      MESSAGE="$2"
      shift 2
      ;;
    --loop)
      [[ $# -ge 2 ]] || die "--loop requires a value"
      LOOP="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

# ── Validate reason ───────────────────────────────────────────────────────────

if ! valid_reason "$REASON"; then
  echo "ERROR: unknown termination reason: '$REASON'" >&2
  echo "Valid reasons: completed user_abort token_budget stop_hook max_turns unrecoverable_error" >&2
  exit 1
fi

# ── Build JSON ────────────────────────────────────────────────────────────────

EXIT_CODE=$(reason_to_exit_code "$REASON")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

# Escape message for JSON (basic: backslash and double-quote)
MESSAGE_ESCAPED=$(printf '%s' "$MESSAGE" | sed 's/\\/\\\\/g; s/"/\\"/g')

JSON="{\"ts\":\"${TIMESTAMP}\",\"loop\":\"${LOOP}\",\"reason\":\"${REASON}\",\"message\":\"${MESSAGE_ESCAPED}\",\"exit_code\":${EXIT_CODE}}"

# ── Output to stdout ──────────────────────────────────────────────────────────

echo "$JSON"

# ── Persist to jsonl ──────────────────────────────────────────────────────────

# Resolve repo root: script lives in scripts/, repo root is one level up.
# Allow override via SAVIA_REPO_ROOT for tests.
REPO_ROOT="${SAVIA_REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

STATE_DIR="${REPO_ROOT}/output/loop-state/${LOOP}"
mkdir -p "$STATE_DIR"

STATE_FILE="${STATE_DIR}/terminal-state.jsonl"
echo "$JSON" >> "$STATE_FILE"

# ── Exit with mapped code ─────────────────────────────────────────────────────

exit "$EXIT_CODE"
