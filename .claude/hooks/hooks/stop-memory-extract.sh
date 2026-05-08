#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# stop-memory-extract.sh — SPEC-013v2: Deep memory extraction at session stop
# Hook: Stop | Timeout: 10 min (vs SessionEnd's 1.5s)
# Extracts decisions, failures, discoveries, references from session context.

# Tier: standard
LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  source "$LIB_DIR/profile-gate.sh"
  profile_gate "standard"
fi
if [[ -f "$LIB_DIR/memory-extract-lib.sh" ]]; then
  source "$LIB_DIR/memory-extract-lib.sh"
fi

INPUT=$(cat 2>/dev/null || true)

PROJ_DIR="${CLAUDE_PROJECT_DIR:-${OPENCODE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}}"
PROJ_SLUG=$(echo "$PROJ_DIR" | sed 's|[/:\]|-|g; s|^-||')
MEMORY_DIR="$HOME/.savia-memory/sessions/$(date +%Y-%m-%d)"
LEGACY_MEMORY_DIR="$HOME/.claude/projects/$PROJ_SLUG/memory"
SESSION_HOT="$MEMORY_DIR/session-hot.md"
ACTION_LOG="$HOME/.savia/session-actions.jsonl"
MEMORY_MD="$MEMORY_DIR/MEMORY.md"

# Copy hot file from legacy if it exists there and not in canonical
if [[ ! -f "$SESSION_HOT" ]] && [[ -f "$LEGACY_MEMORY_DIR/session-hot.md" ]]; then
  mkdir -p "$MEMORY_DIR"
  cp "$LEGACY_MEMORY_DIR/session-hot.md" "$SESSION_HOT" 2>/dev/null || true
fi

[[ ! -f "$SESSION_HOT" ]] && [[ ! -f "$ACTION_LOG" ]] && exit 0
mkdir -p "$MEMORY_DIR"

TIMESTAMP=$(date +%Y-%m-%d)
ITEMS_SAVED=0

# ── PHASE 1: Scan session-hot for decisions/corrections ──
DECISIONS="" CORRECTIONS="" HOT_TEXT=""
if [[ -f "$SESSION_HOT" ]] && [[ -s "$SESSION_HOT" ]]; then
  HOT_TEXT=$(cat "$SESSION_HOT")
  DECISIONS=$(echo "$HOT_TEXT" | grep -ioE '(Decisions?:)[^|]*' | head -3 \
    | sed 's/Decisions\?:\s*//' | tr '\n' '; ' || true)
  CORRECTIONS=$(echo "$HOT_TEXT" | grep -ioE '(Corrections?:)[^|]*' | head -3 \
    | sed 's/Corrections\?:\s*//' | tr '\n' '; ' || true)
fi

# ── PHASE 2: Scan action log for repeated failures ──
REPEATED_FAILURES=""
if [[ -f "$ACTION_LOG" ]]; then
  REPEATED_FAILURES=$(grep '"attempt":[3-9]' "$ACTION_LOG" 2>/dev/null \
    | grep -o '"action":"[^"]*"' | cut -d'"' -f4 | sort | uniq -c | sort -rn \
    | head -3 | awk '{print $2}' | tr '\n' ', ' || true)
fi

# ── PHASE 2b: Discovery extraction ──
DISCOVERIES=""
if [[ -n "$HOT_TEXT" ]]; then
  DISCOVERIES=$(echo "$HOT_TEXT" | grep -ioE \
    '(bug was|caused by|root cause|raiz|resulta que|turned out|issue was|problema era)[^|;]{10,80}' \
    | head -3 | tr '\n' '; ' || true)
fi

# ── PHASE 2c: Reference extraction (URLs) ──
REFERENCES=""
if [[ -n "$HOT_TEXT" ]]; then
  REFERENCES=$(echo "$HOT_TEXT" | grep -oE 'https?://[^ ")<>]+' \
    | sort -u | head -3 | tr '\n' '; ' || true)
fi

# ── PHASE 3: Persist with quality gates ──
if [[ -n "$DECISIONS" ]]; then
  SAFE=$(echo "$DECISIONS" | head -c 200 | tr '"' "'")
  if passes_quality_gate "$SAFE" "$MEMORY_DIR"; then
    save_memory_file "$MEMORY_DIR" "$MEMORY_MD" \
      "session_decisions_${TIMESTAMP}.md" "Session decisions ${TIMESTAMP}" \
      "Decisions extracted — ${SAFE:0:60}" "project" "$SAFE"
  fi
fi

if [[ -n "$REPEATED_FAILURES" ]]; then
  SAFE=$(echo "$REPEATED_FAILURES" | head -c 150 | tr '"' "'")
  if passes_quality_gate "Repeated failures: $SAFE" "$MEMORY_DIR"; then
    save_memory_file "$MEMORY_DIR" "$MEMORY_MD" \
      "session_failures_${TIMESTAMP}.md" "Repeated failures ${TIMESTAMP}" \
      "Actions that failed 3+ times — ${SAFE:0:60}" "feedback" \
      "Repeated failures: ${SAFE}"
  fi
fi

if [[ -n "$DISCOVERIES" ]]; then
  SAFE=$(echo "$DISCOVERIES" | head -c 200 | tr '"' "'")
  if passes_quality_gate "$SAFE" "$MEMORY_DIR"; then
    save_memory_file "$MEMORY_DIR" "$MEMORY_MD" \
      "session_discoveries_${TIMESTAMP}.md" "Session discoveries ${TIMESTAMP}" \
      "Root causes and insights — ${SAFE:0:60}" "project" "$SAFE"
  fi
fi

if [[ -n "$REFERENCES" ]]; then
  SAFE=$(echo "$REFERENCES" | head -c 200 | tr '"' "'")
  if passes_quality_gate "$SAFE" "$MEMORY_DIR"; then
    save_memory_file "$MEMORY_DIR" "$MEMORY_MD" \
      "session_references_${TIMESTAMP}.md" "Session references ${TIMESTAMP}" \
      "URLs and docs referenced — ${SAFE:0:60}" "reference" "$SAFE"
  fi
fi

# ── PHASE 4: Archive action log ──
if [[ -f "$ACTION_LOG" ]]; then
  mv "$ACTION_LOG" "$HOME/.savia/session-actions-$(date +%Y%m%d-%H%M%S).jsonl" 2>/dev/null || true
fi

[[ $ITEMS_SAVED -gt 0 ]] && echo "Session stop: $ITEMS_SAVED items extracted to memory."
exit 0
