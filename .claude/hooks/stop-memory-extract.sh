#!/bin/bash
set -uo pipefail
# stop-memory-extract.sh — SPEC-013v2: Deep memory extraction at session stop
# Hook: Stop | Timeout: 10 min (vs SessionEnd's 1.5s)
# Strategy: scan session-hot.md + session-actions.jsonl, extract valuable
# items, persist to auto-memory. This is the heavy extraction that
# SessionEnd (1.5s) cannot do.

# Tier: standard
LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh"
  profile_gate "standard"
fi

INPUT=$(cat 2>/dev/null || true)

MEMORY_DIR="$HOME/.claude/projects/-home-monica-claude/memory"
SESSION_HOT="$MEMORY_DIR/session-hot.md"
ACTION_LOG="$HOME/.savia/session-actions.jsonl"
MEMORY_MD="$MEMORY_DIR/MEMORY.md"

# Skip if nothing to extract
[[ ! -f "$SESSION_HOT" ]] && [[ ! -f "$ACTION_LOG" ]] && exit 0

# ── PHASE 1: Scan session-hot.md for decisions/corrections ──
DECISIONS=""
CORRECTIONS=""
if [[ -f "$SESSION_HOT" ]] && [[ -s "$SESSION_HOT" ]]; then
  DECISIONS=$(grep -ioE '(Decisions?:)[^|]*' "$SESSION_HOT" | head -3 | sed 's/Decisions\?:\s*//' | tr '\n' '; ' || true)
  CORRECTIONS=$(grep -ioE '(Corrections?:)[^|]*' "$SESSION_HOT" | head -3 | sed 's/Corrections\?:\s*//' | tr '\n' '; ' || true)
fi

# ── PHASE 2: Scan action log for patterns ──
REPEATED_FAILURES=""
if [[ -f "$ACTION_LOG" ]]; then
  # Find actions that failed 3+ times (pattern worth remembering)
  REPEATED_FAILURES=$(grep '"attempt":[3-9]' "$ACTION_LOG" 2>/dev/null \
    | grep -o '"action":"[^"]*"' | cut -d'"' -f4 | sort | uniq -c | sort -rn \
    | head -3 | awk '{print $2}' | tr '\n' ', ' || true)
fi

# ── PHASE 3: Persist valuable items ──
ITEMS_SAVED=0

# Persist decisions as project memory
if [[ -n "$DECISIONS" ]] && [[ ${#DECISIONS} -gt 20 ]]; then
  SAFE_DECISIONS=$(echo "$DECISIONS" | head -c 200 | tr '"' "'")
  TIMESTAMP=$(date +%Y-%m-%d)
  # Check for duplicates before saving
  if ! grep -qF "${SAFE_DECISIONS:0:40}" "$MEMORY_DIR"/*.md 2>/dev/null; then
    cat > "$MEMORY_DIR/session_decisions_${TIMESTAMP}.md" << MEMEOF
---
name: Session decisions ${TIMESTAMP}
description: Decisions extracted from session stop — ${SAFE_DECISIONS:0:60}
type: project
---

${SAFE_DECISIONS}

**Why:** Extracted automatically at session stop (SPEC-013v2).
**How to apply:** Review and incorporate into project decisions if still relevant.
MEMEOF
    ITEMS_SAVED=$((ITEMS_SAVED + 1))
  fi
fi

# Persist repeated failures as feedback memory
if [[ -n "$REPEATED_FAILURES" ]]; then
  SAFE_FAILURES=$(echo "$REPEATED_FAILURES" | head -c 150 | tr '"' "'")
  TIMESTAMP=$(date +%Y-%m-%d)
  if ! grep -qF "${SAFE_FAILURES:0:30}" "$MEMORY_DIR"/*.md 2>/dev/null; then
    cat > "$MEMORY_DIR/session_failures_${TIMESTAMP}.md" << MEMEOF
---
name: Repeated failures ${TIMESTAMP}
description: Actions that failed 3+ times this session — ${SAFE_FAILURES:0:60}
type: feedback
---

Repeated failures: ${SAFE_FAILURES}

**Why:** Pattern of repeated failures indicates a systemic issue.
**How to apply:** Investigate root cause before retrying same approach.
MEMEOF
    ITEMS_SAVED=$((ITEMS_SAVED + 1))
  fi
fi

# ── PHASE 4: Cleanup action log (consumed) ──
if [[ -f "$ACTION_LOG" ]]; then
  # Archive instead of delete
  ARCHIVE="$HOME/.savia/session-actions-$(date +%Y%m%d-%H%M%S).jsonl"
  mv "$ACTION_LOG" "$ARCHIVE" 2>/dev/null || true
fi

# Output summary (visible to Claude on next session)
if [[ $ITEMS_SAVED -gt 0 ]]; then
  echo "Session stop: $ITEMS_SAVED items extracted to memory."
fi

exit 0
