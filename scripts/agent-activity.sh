#!/usr/bin/env bash
# agent-activity.sh — Agent activity dashboard
# Reads trace logs from agent-trace-log hook to show agent accountability.
#
# Usage: bash scripts/agent-activity.sh [--summary | --json | --recent N]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="${1:---summary}"
TRACE_DIR="$HOME/.pm-workspace"
TRACE_FILE="$TRACE_DIR/agent-trace.jsonl"

if [ ! -f "$TRACE_FILE" ]; then
  echo "No agent trace data found at $TRACE_FILE"
  echo "Agent traces are captured by the agent-trace-log hook."
  exit 0
fi

TOTAL=$(wc -l < "$TRACE_FILE")

if [ "$MODE" = "--json" ]; then
  jq -s '{
    total_invocations: length,
    agents: (group_by(.agent) | map({
      name: .[0].agent,
      invocations: length,
      avg_duration_ms: ([.[].duration_ms] | add / length | floor),
      outcomes: (group_by(.outcome) | map({key: .[0].outcome, value: length}) | from_entries)
    }) | sort_by(-.invocations))
  }' "$TRACE_FILE" 2>/dev/null || echo '{"error": "Invalid trace data"}'

elif [ "$MODE" = "--recent" ]; then
  N="${2:-10}"
  tail -"$N" "$TRACE_FILE" | jq -r '"\(.timestamp) | \(.agent) | \(.outcome) | \(.duration_ms)ms"' 2>/dev/null

else
  echo "═══════════════════════════════════════════════════"
  echo "  🤖 Agent Activity Dashboard"
  echo "═══════════════════════════════════════════════════"
  echo ""
  echo "  Total invocations: $TOTAL"
  echo ""

  if command -v jq >/dev/null 2>&1; then
    echo "  Top agents by invocation count:"
    jq -rs 'group_by(.agent) | map({name: .[0].agent, count: length}) | sort_by(-.count) | .[:10] | .[] | "    \(.name): \(.count)"' "$TRACE_FILE" 2>/dev/null
    echo ""

    success=$(jq -r '.outcome' "$TRACE_FILE" 2>/dev/null | grep -c "success" || true)
    failure=$(jq -r '.outcome' "$TRACE_FILE" 2>/dev/null | grep -c "failure" || true)
    echo "  Outcomes: $success success, $failure failures"
  else
    echo "  (Install jq for detailed breakdown)"
  fi

  echo ""
  echo "═══════════════════════════════════════════════════"
fi
