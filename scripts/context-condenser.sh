#!/bin/bash
# context-condenser.sh — SE-200: rolling window context compression
# Inspired by OpenHands LLMSummarizingCondenser pattern
# Ref: docs/propuestas/SE-200-llm-condenser.md
set -uo pipefail

MAX_SIZE=${SAVIA_CONDENSER_MAX_SIZE:-120}
KEEP_HEAD=${SAVIA_CONDENSER_KEEP_HEAD:-4}
KEEP_TAIL=${SAVIA_CONDENSER_KEEP_TAIL:-60}
SESSION_LOG="${PROJECT_ROOT:-$(pwd)}/output/session-action-log.jsonl"
DRY_RUN=false

usage() {
  echo "Usage: context-condenser.sh [--dry-run] [--stats] [--session-log <path>]" >&2
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --help)       usage ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --stats)
      if [[ ! -f "$SESSION_LOG" ]]; then
        echo "context-condenser: no session log at $SESSION_LOG" >&2
        exit 0
      fi
      LINE_COUNT=$(wc -l < "$SESSION_LOG")
      echo "context-condenser stats: events=$LINE_COUNT max_size=$MAX_SIZE keep_head=$KEEP_HEAD keep_tail=$KEEP_TAIL"
      if [[ "$LINE_COUNT" -gt "$MAX_SIZE" ]]; then
        MIDDLE=$(( LINE_COUNT - KEEP_HEAD - KEEP_TAIL ))
        [[ "$MIDDLE" -lt 0 ]] && MIDDLE=0
        echo "  would compress: middle=$MIDDLE events"
      else
        echo "  no compression needed"
      fi
      exit 0
      ;;
    --session-log)
      shift
      SESSION_LOG="${1:-}"
      shift
      ;;
    *)
      echo "context-condenser: unknown option '${1}'" >&2
      usage
      ;;
  esac
done

if [[ ! -f "$SESSION_LOG" ]]; then
  echo "context-condenser: no session log found at $SESSION_LOG" >&2
  exit 0
fi

LINE_COUNT=$(wc -l < "$SESSION_LOG")
if [[ "$LINE_COUNT" -le "$MAX_SIZE" ]]; then
  echo "context-condenser: $LINE_COUNT events <= $MAX_SIZE threshold — no condensation needed"
  exit 0
fi

if $DRY_RUN; then
  MIDDLE=$(( LINE_COUNT - KEEP_HEAD - KEEP_TAIL ))
  [[ "$MIDDLE" -lt 0 ]] && MIDDLE=0
  echo "context-condenser: DRY RUN — would condense $LINE_COUNT events (keep head=$KEEP_HEAD + tail=$KEEP_TAIL, compress middle=$MIDDLE)"
  exit 0
fi

# Delegate to Python for actual condensation logic
python3 "$(dirname "$0")/context-condenser.py" \
  --log "$SESSION_LOG" \
  --max-size "$MAX_SIZE" \
  --keep-head "$KEEP_HEAD" \
  --keep-tail "$KEEP_TAIL"
