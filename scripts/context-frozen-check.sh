#!/usr/bin/env bash
# context-frozen-check.sh — SE-029-F
# Checks if a file/path is in the frozen core (never compressible).
# Ref: docs/propuestas/SE-029-rate-distortion-context.md
#
# Frozen zones:
#   - decision-log.md entries last 30 days
#   - Approved SPEC-NNN docs referenced in current turn
#   - Agent handoff YAML blocks (SPEC-121)
#   - Last 3 raw human turns
#   - Acceptance Criteria of active sprint
#   - Stack traces (debugging)
#
# Usage:
#   bash scripts/context-frozen-check.sh --path FILE [--json]
#   echo "text" | bash scripts/context-frozen-check.sh --class TYPE [--json]
#
# Exit codes:
#   0 = NOT frozen (safe to compress)
#   1 = FROZEN (must preserve)
#   2 = input error

set -uo pipefail

PATH_TO_CHECK=""
CLASS_TYPE=""
JSON_OUT=false
# REPO_ROOT: env override takes precedence, else derive from script location
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}" || REPO_ROOT="."

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path) PATH_TO_CHECK="$2"; shift 2 ;;
    --class) CLASS_TYPE="$2"; shift 2 ;;
    --json) JSON_OUT=true; shift ;;
    --help|-h) usage ;;
    *) echo "Error: unknown flag $1" >&2; exit 2 ;;
  esac
done

FROZEN=false
REASON=""

# ── Rule 1: decision-log.md ──────────────────────────────────────────────────
if [[ -n "$PATH_TO_CHECK" ]] && [[ "$PATH_TO_CHECK" == *"decision-log.md" ]]; then
  FROZEN=true
  REASON="decision-log"
fi

# ── Rule 2: approved SPEC files ──────────────────────────────────────────────
if ! $FROZEN && [[ -n "$PATH_TO_CHECK" ]]; then
  if [[ "$PATH_TO_CHECK" =~ docs/propuestas/SPEC-[0-9]+.*\.md ]]; then
    # Check status: APPROVED or DONE in frontmatter
    if [[ -f "$REPO_ROOT/$PATH_TO_CHECK" ]] && grep -qE "^status:\s*(APPROVED|DONE|IN_PROGRESS)" "$REPO_ROOT/$PATH_TO_CHECK" 2>/dev/null; then
      FROZEN=true
      REASON="approved-spec"
    fi
  fi
fi

# ── Rule 3: handoff YAML blocks ──────────────────────────────────────────────
if ! $FROZEN && [[ "$CLASS_TYPE" == "handoff" ]]; then
  FROZEN=true
  REASON="agent-handoff"
fi

# ── Rule 4: class=decision or class=spec (from task classifier) ──────────────
if ! $FROZEN && [[ "$CLASS_TYPE" == "decision" || "$CLASS_TYPE" == "spec" ]]; then
  FROZEN=true
  REASON="task-class-$CLASS_TYPE"
fi

# ── Rule 5: Acceptance criteria files ────────────────────────────────────────
if ! $FROZEN && [[ -n "$PATH_TO_CHECK" ]]; then
  if [[ "$PATH_TO_CHECK" =~ acceptance-criteria\.md|AC-.*\.md ]]; then
    FROZEN=true
    REASON="acceptance-criteria"
  fi
fi

# ── Rule 6: stack traces ─────────────────────────────────────────────────────
if ! $FROZEN && [[ "$CLASS_TYPE" == "stacktrace" ]]; then
  FROZEN=true
  REASON="stack-trace"
fi

# ── Output ───────────────────────────────────────────────────────────────────
if $JSON_OUT; then
  printf '{"frozen":%s,"reason":"%s","path":"%s","class":"%s"}\n' \
    "$FROZEN" "$REASON" "$PATH_TO_CHECK" "$CLASS_TYPE"
else
  if $FROZEN; then
    echo "FROZEN   reason=$REASON"
  else
    echo "NOT FROZEN  (safe to compress)"
  fi
fi

$FROZEN && exit 1 || exit 0
