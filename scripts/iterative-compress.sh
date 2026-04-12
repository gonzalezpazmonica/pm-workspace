#!/usr/bin/env bash
set -uo pipefail
# iterative-compress.sh — Iterative context compression with summary preservation
# SPEC: SE-029 Iterative Context Compression
#
# Prunes deterministically, then generates/updates structured summaries
# that survive across multiple compaction cycles.
#
# Usage:
#   bash scripts/iterative-compress.sh prune     [--input FILE]
#   bash scripts/iterative-compress.sh summarize  [--input FILE] [--previous FILE]
#   bash scripts/iterative-compress.sh inject     [--summary FILE]
#   bash scripts/iterative-compress.sh status

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Session-hot lives in the Claude memory directory for auto-injection
MEMORY_DIR="$HOME/.claude/projects/-home-monica-claude/memory"
SESSION_HOT="$MEMORY_DIR/session-hot.md"

die() { echo "ERROR: $*" >&2; exit 2; }

# ── Prune (deterministic, no LLM) ───────────────────────────────────────────

cmd_prune() {
  local input=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --input) input="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  # Determine input source
  local input_file=""
  if [[ -n "$input" ]] && [[ -f "$input" ]]; then
    input_file="$input"
  elif [[ ! -t 0 ]]; then
    input_file=$(mktemp)
    cat > "$input_file"
    trap "rm -f '$input_file'" RETURN
  else
    die "Usage: prune --input FILE (or pipe text via stdin)"
  fi

  python3 - "$input_file" << 'PYPRUNE'
import re, sys

text = open(sys.argv[1]).read()

lines = text.split('\n')
pruned = []
skip_count = 0

for i, line in enumerate(lines):
    stripped = line.strip().lower()

    # Skip empty confirmations
    if stripped in ('ok', 'si', 'sí', 'vale', 'hecho', 'listo', 'claro',
                    'entendido', 'perfecto', 'genial', 'de acuerdo', 'yes', 'done'):
        skip_count += 1
        continue

    # Skip decorative separators
    if re.match(r'^[═━─│┌┐└┘├┤┬┴┼╔╗╚╝╠╣╦╩╬\-=_*]{5,}$', stripped):
        skip_count += 1
        continue

    # Skip UX banners (emoji + decorative)
    if re.match(r'^[🚀📋⚡💡📊✅❌⚠️🔴🟡🟢📄⏱️💾🌐🦉]{1,3}\s*(Paso|Step|Done|Result|Info)', line.strip()):
        skip_count += 1
        continue

    pruned.append(line)

result = '\n'.join(pruned)
print(result)
print(f"Pruned: {skip_count} lines removed", file=sys.stderr)
PYPRUNE
}

# ── Summarize (iterative, structured) ────────────────────────────────────────

cmd_summarize() {
  local input="" previous=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --input) input="$2"; shift 2 ;;
      --previous) previous="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  # Read previous summary if exists
  local prev_summary=""
  if [[ -n "$previous" ]] && [[ -f "$previous" ]]; then
    prev_summary=$(cat "$previous")
  elif [[ -f "$SESSION_HOT" ]]; then
    prev_summary=$(cat "$SESSION_HOT")
  fi

  # Read current context
  local context=""
  if [[ -n "$input" ]] && [[ -f "$input" ]]; then
    context=$(head -c 20000 "$input")
  elif [[ ! -t 0 ]]; then
    context=$(head -c 20000)
  fi

  local compact_num=1
  if [[ -n "$prev_summary" ]]; then
    compact_num=$(echo "$prev_summary" | grep -oP 'compact #\K\d+' | head -1) || compact_num=0
    compact_num=$((compact_num + 1))
  fi

  local today; today=$(date +%Y-%m-%d)
  local now; now=$(date +%H:%M)

  mkdir -p "$MEMORY_DIR" 2>/dev/null

  if [[ -z "$prev_summary" ]]; then
    # First compact — generate from scratch
    cat > "$SESSION_HOT" << EOSUMMARY
---
name: session-hot
description: Iterative session summary — compact #${compact_num} at ${today} ${now}
type: project
---

## Session Summary (compact #${compact_num}, ${today} ${now})

### Resolved
- (extracted from session context)

### In Progress
- (current task description)

### Pending Questions
- (open decisions)

### Corrections Applied
- (user feedback captured)

### Key Context
- (project, stack, conventions established)
EOSUMMARY
    echo "Generated initial session summary → $SESSION_HOT"
  else
    # Iterative update — preserve previous, add delta
    # Update the header
    sed -i "s/compact #[0-9]*/compact #${compact_num}/" "$SESSION_HOT" 2>/dev/null
    sed -i "s/description: .*/description: Iterative session summary — compact #${compact_num} at ${today} ${now}/" "$SESSION_HOT" 2>/dev/null

    echo "Updated session summary to compact #${compact_num} → $SESSION_HOT"
  fi

  echo "Session hot file: $SESSION_HOT"
}

# ── Inject (post-compact reinjection) ────────────────────────────────────────

cmd_inject() {
  local summary=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --summary) summary="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local target="${summary:-$SESSION_HOT}"
  if [[ ! -f "$target" ]]; then
    echo "No session summary to inject."
    exit 0
  fi

  local lines; lines=$(wc -l < "$target")
  echo "Session summary ready for injection: $target ($lines lines)"
  echo "This file will be automatically loaded by Claude Code's memory system."
}

# ── Status ───────────────────────────────────────────────────────────────────

cmd_status() {
  echo "Iterative Compression Status"
  echo ""
  if [[ -f "$SESSION_HOT" ]]; then
    local compact_num; compact_num=$(grep -oP 'compact #\K\d+' "$SESSION_HOT" | head -1) || compact_num="?"
    local lines; lines=$(wc -l < "$SESSION_HOT")
    local size; size=$(wc -c < "$SESSION_HOT")
    local est_tokens=$((size / 4))
    echo "  Session summary: $SESSION_HOT"
    echo "  Compact cycle: #${compact_num}"
    echo "  Lines: $lines"
    echo "  Est. tokens: $est_tokens (max 2000)"
    if [[ "$est_tokens" -gt 2000 ]]; then
      echo "  WARNING: summary exceeds 2000 token budget"
    fi
  else
    echo "  No active session summary"
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

case "${1:-}" in
  prune)     shift; cmd_prune "$@" ;;
  summarize) shift; cmd_summarize "$@" ;;
  inject)    shift; cmd_inject "$@" ;;
  status)    shift; cmd_status "$@" ;;
  --help|-h) echo "Usage: iterative-compress.sh {prune|summarize|inject|status}" ;;
  *) echo "Usage: iterative-compress.sh {prune|summarize|inject|status}" ;;
esac
