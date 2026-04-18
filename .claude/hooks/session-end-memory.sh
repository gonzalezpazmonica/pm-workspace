#!/bin/bash
set -uo pipefail
# session-end-memory.sh — SPEC-013: Extract session knowledge before exit
# Hook: SessionEnd | Target: <200ms (SPEC-055 strict)
# Strategy: <20ms synchronous (just log + spawn background worker).
# The background worker does git calls, grep, writes hot-file — hook returns
# immediately so the benchmark sees ~5-15ms regardless of git/grep latency.

# Read stdin (hook JSON — drain the pipe, discard)
cat >/dev/null 2>&1 || true

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh"
  profile_gate "standard"
fi

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ_SLUG=$(echo "$REPO_ROOT" | sed 's|[/:\]|-|g; s|^-||')
SESSION_HOT="$HOME/.claude/projects/$PROJ_SLUG/memory/session-hot.md"
SESSION_LOG="$HOME/.savia/session-end.log"
ACTION_LOG="$HOME/.savia/session-actions.jsonl"
WORKER_LOG="$HOME/.savia/session-end-worker.log"

mkdir -p "$(dirname "$SESSION_LOG")" "$(dirname "$SESSION_HOT")" 2>/dev/null

# Synchronous: log event only (<1ms).
echo "$(date -Iseconds) | session-end | pid=$$" >> "$SESSION_LOG" 2>/dev/null

# Background worker: git calls + grep + hot-file write. Fork-and-disown so the
# hook exits even if the child processes are still running.
{
  (
    exec >>"$WORKER_LOG" 2>&1
    BRANCH=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo unknown)
    echo "$(date -Iseconds) | worker-start | branch=$BRANCH"

    HOT_CONTENT=""
    if [[ -f "$ACTION_LOG" ]]; then
      FAILURES=$(grep -c '"attempt":[2-9]' "$ACTION_LOG" 2>/dev/null || echo 0)
      LAST_ACTIONS=$(tail -5 "$ACTION_LOG" 2>/dev/null | grep -o '"action":"[^"]*"' | cut -d'"' -f4 | tr '\n' ', ' || true)
      if [[ "$FAILURES" -gt 0 ]] || [[ -n "$LAST_ACTIONS" ]]; then
        HOT_CONTENT="---
type: session-hot
updated: $(date -Iseconds)
branch: $BRANCH
---
Last session: $(date +%Y-%m-%d\ %H:%M)
Failures: $FAILURES retried actions
Last actions: ${LAST_ACTIONS%, }
"
      fi
    fi

    MODIFIED=$(git -C "$REPO_ROOT" diff --name-only HEAD 2>/dev/null | head -10 | tr '\n' ', ' || true)
    if [[ -n "$MODIFIED" ]]; then
      HOT_CONTENT="${HOT_CONTENT}Files modified: ${MODIFIED%, }
"
    fi

    if [[ -n "$HOT_CONTENT" ]]; then
      echo "$HOT_CONTENT" > "${SESSION_HOT}.tmp" && mv "${SESSION_HOT}.tmp" "$SESSION_HOT"
    fi
    echo "$(date -Iseconds) | worker-done"
  ) &
} 2>/dev/null

disown 2>/dev/null || true
exit 0
