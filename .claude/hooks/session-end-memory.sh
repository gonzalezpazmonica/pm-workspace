#!/bin/bash
set -uo pipefail
# session-end-memory.sh — SPEC-013: Extract session knowledge before exit
# Hook: SessionEnd | Timeout: 1.5s (hard limit from Claude Code)
# Strategy: fast extraction of session-action-log + last compact summary.
# Heavy processing deferred to background log; this hook writes a hot-file
# that post-compaction.sh reads on next session start.

# Read stdin (hook JSON — contains session metadata)
INPUT=$(cat 2>/dev/null || true)

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh"
  profile_gate "standard"
fi

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ_SLUG=$(echo "$PROJ_DIR" | sed 's|[/:\]|-|g; s|^-||')
SESSION_HOT="$HOME/.claude/projects/$PROJ_SLUG/memory/session-hot.md"
SESSION_LOG="$HOME/.savia/session-end.log"
ACTION_LOG="$HOME/.savia/session-actions.jsonl"

mkdir -p "$(dirname "$SESSION_LOG")" "$(dirname "$SESSION_HOT")"

# 1. Log the event (always, <1ms)
echo "$(date -Iseconds) | session-end | pid=$$ | branch=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo unknown)" \
  >> "$SESSION_LOG" 2>/dev/null

# 2. Extract from session-action-log: failures, retries, last actions
HOT_CONTENT=""
if [[ -f "$ACTION_LOG" ]]; then
  # Count failures this session (actions with attempt > 1)
  FAILURES=$(grep -c '"attempt":[2-9]' "$ACTION_LOG" 2>/dev/null || echo 0)
  LAST_ACTIONS=$(tail -5 "$ACTION_LOG" 2>/dev/null | grep -o '"action":"[^"]*"' | cut -d'"' -f4 | tr '\n' ', ' || true)

  if [[ "$FAILURES" -gt 0 ]] || [[ -n "$LAST_ACTIONS" ]]; then
    HOT_CONTENT="---
type: session-hot
updated: $(date -Iseconds)
---
Last session: $(date +%Y-%m-%d %H:%M)
Failures: $FAILURES retried actions
Last actions: ${LAST_ACTIONS%, }
"
  fi
fi

# 3. Capture modified files (fast: git status)
MODIFIED=$(git -C "$REPO_ROOT" diff --name-only HEAD 2>/dev/null | head -10 | tr '\n' ', ' || true)
if [[ -n "$MODIFIED" ]]; then
  HOT_CONTENT="${HOT_CONTENT}Files modified: ${MODIFIED%, }
"
fi

# 4. Write hot-file for next session (atomic write)
if [[ -n "$HOT_CONTENT" ]]; then
  echo "$HOT_CONTENT" > "${SESSION_HOT}.tmp" && mv "${SESSION_HOT}.tmp" "$SESSION_HOT"
fi

# NEVER block session exit
exit 0
