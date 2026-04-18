#!/bin/bash
# memory-prime-hook.sh — Auto-prime memory context on each user prompt
# Runs as PreToolUse async hook. Lightweight: exits fast if no store.
# Feeds context-auto-prime.py with the user's message for domain routing.
set -uo pipefail

STORE="${PROJECT_ROOT:-$HOME/claude}/output/.memory-store.jsonl"
PRIME_SCRIPT="${PROJECT_ROOT:-$HOME/claude}/scripts/context-auto-prime.py"
PREFETCH_SCRIPT="${PROJECT_ROOT:-$HOME/claude}/scripts/context-prefetch.py"

# Exit fast if no store or no scripts
[ -f "$STORE" ] || exit 0
command -v python3 &>/dev/null || exit 0

# Read user input from stdin (hook receives tool context)
INPUT=$(cat 2>/dev/null || echo "")
[ -z "$INPUT" ] && exit 0

# Extract query-like content (best effort)
QUERY=$(echo "$INPUT" | head -c 500)

# Auto-prime: score and select relevant memories
# Bounded concurrency: explicit cap on background python3 spawns.
# Defense-in-depth even though --top 3 upstream limits expected topics.
# See docs/rules/domain/bounded-concurrency.md (Bluesky outage 2026-04 lesson).
MAX_PARALLEL=5
if [ -f "$PRIME_SCRIPT" ]; then
  PRIMED=$(python3 "$PRIME_SCRIPT" prime "$QUERY" --store "$STORE" --top 3 --max-tokens 200 2>/dev/null || echo "")
  if [ -n "$PRIMED" ] && echo "$PRIMED" | grep -q "Auto-primed"; then
    # Log the prime for access tracking — bounded fan-out
    pids=()
    echo "$PRIMED" | grep "^-" | while read -r line; do
      # Hard cap: if MAX_PARALLEL background jobs are in flight, wait for any
      # to finish before spawning the next. Prevents unbounded fan-out if
      # upstream ever forgets --top N or returns unexpectedly many rows.
      while [ "$(jobs -rp | wc -l)" -ge "$MAX_PARALLEL" ]; do
        wait -n 2>/dev/null || break
      done
      TOPIC=$(echo "$line" | grep -oP '\(.*?,' | head -1 | tr -d '(,')
      [ -f "$PREFETCH_SCRIPT" ] && python3 "$PREFETCH_SCRIPT" access "$TOPIC" --store "$STORE" 2>/dev/null &
    done
    # Drain outstanding background work before returning (hook exits cleanly)
    wait 2>/dev/null || true
  fi
fi

exit 0
