#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# emotional-regulation-monitor.sh — Session stress assessment at stop
# Hook: Stop | Timeout: 10s | Tier: standard
# Source: Anthropic "Emotion concepts in LLMs" (2026-04-02)
# Assesses accumulated session stress and persists high-friction
# sessions to memory for future awareness.
# Exit 0 always (never blocks session stop).

# Tier: standard
LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh"
  profile_gate "standard"
fi

INPUT=$(cat 2>/dev/null || true)

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
TRACKER="$REPO_ROOT/scripts/emotional-state-tracker.sh"

# Skip if tracker doesn't exist
[[ ! -f "$TRACKER" ]] && exit 0

STATE_FILE="$HOME/.savia/session-stress.json"
[[ ! -f "$STATE_FILE" ]] && exit 0

# ── Get session stress score ──
# Extract first integer from tracker output; fallback 0 if non-numeric
# (Prevents set -u crash when tracker returns error message with unbound tokens)
RAW_SCORE=$(bash "$TRACKER" score 2>/dev/null || echo "0")
SCORE=$(echo "$RAW_SCORE" | head -1 | grep -oE '[0-9]+' | head -1)
SCORE="${SCORE:-0}"

# ── Low friction: nothing to do ──
if [[ "$SCORE" -lt 5 ]]; then
  # Reset for next session
  bash "$TRACKER" reset >/dev/null 2>&1 || true
  exit 0
fi

# ── Significant friction (5+): persist to memory ──
PROJ_SLUG=$(echo "$REPO_ROOT" | sed 's|[/:\]|-|g; s|^-||')
MEMORY_DIR="$HOME/.claude/projects/$PROJ_SLUG/memory"
mkdir -p "$MEMORY_DIR" 2>/dev/null || true

# Collect details
STATUS=$(bash "$TRACKER" status 2>/dev/null || echo "score: $SCORE")
TIMESTAMP=$(date +%Y-%m-%d)

# Determine level
LEVEL="significant_friction"
if [[ $SCORE -ge 9 ]]; then LEVEL="overload"
elif [[ $SCORE -ge 7 ]]; then LEVEL="high_stress"
fi

# Extract event counts from state file
RETRIES=$(grep -o '"retry":[0-9]*' "$STATE_FILE" | cut -d: -f2 || echo "0")
FAILURES=$(grep -o '"failure":[0-9]*' "$STATE_FILE" | cut -d: -f2 || echo "0")
ESCALATIONS=$(grep -o '"escalation":[0-9]*' "$STATE_FILE" | cut -d: -f2 || echo "0")
RULE_SKIPS=$(grep -o '"rule_skip":[0-9]*' "$STATE_FILE" | cut -d: -f2 || echo "0")

# Check for duplicates (don't save if similar entry exists today)
if grep -qF "session_stress_${TIMESTAMP}" "$MEMORY_DIR"/MEMORY.md 2>/dev/null; then
  bash "$TRACKER" reset >/dev/null 2>&1 || true
  exit 0
fi

# Persist to memory
MEMORY_FILE="$MEMORY_DIR/session_stress_${TIMESTAMP}.md"
cat > "$MEMORY_FILE" << MEMEOF
---
name: Session stress ${TIMESTAMP}
description: Session had ${LEVEL} (score ${SCORE}/10) — ${RETRIES:-0} retries, ${FAILURES:-0} failures, ${ESCALATIONS:-0} escalations
type: feedback
---

Session stress report (${TIMESTAMP}):
- Frustration score: ${SCORE}/10 (${LEVEL})
- Retries: ${RETRIES:-0}, Failures: ${FAILURES:-0}, Escalations: ${ESCALATIONS:-0}, Rule skips: ${RULE_SKIPS:-0}

**Why:** Anthropic research shows accumulated functional stress degrades output quality.
Sessions with score 5+ indicate approaches that should be changed, not retried harder.
**How to apply:** In similar tasks, try a different approach earlier or escalate sooner.
MEMEOF

# Update MEMORY.md index if it exists
if [[ -f "$MEMORY_DIR/MEMORY.md" ]]; then
  # Add entry if not already there
  if ! grep -qF "session_stress_${TIMESTAMP}" "$MEMORY_DIR/MEMORY.md"; then
    echo "- [Session stress ${TIMESTAMP}](session_stress_${TIMESTAMP}.md) — ${LEVEL} (${SCORE}/10)" >> "$MEMORY_DIR/MEMORY.md"
  fi
fi

# Output summary
echo "Session stress: ${SCORE}/10 (${LEVEL}). Persisted to memory." >&2

# Reset for next session
bash "$TRACKER" reset >/dev/null 2>&1 || true

exit 0
