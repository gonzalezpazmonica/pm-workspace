#!/usr/bin/env bash
# Detector: memory-consolidation (SE-279)
# Checks if memory entries need consolidation.
# Triggers when unconsolidated entries > threshold.

set -uo pipefail

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MEMORY_STORE="${ROOT}/scripts/memory-store.sh"
THRESHOLD="${MEMORY_CONSOLIDATION_THRESHOLD:-10}"

if [[ ! -f "$MEMORY_STORE" ]]; then
  echo '{"triggered":false,"reason":"memory-store.sh not found"}'
  exit 0
fi

# Get memory stats
STATS=$(bash "$MEMORY_STORE" stats 2>/dev/null || echo "")
TOTAL=$(echo "$STATS" | grep -oP 'total.*?\K\d+' | head -1 || echo 0)

if [[ -z "$TOTAL" ]] || [[ "$TOTAL" -eq 0 ]]; then
  echo '{"triggered":false,"reason":"no memory entries"}'
  exit 0
fi

# Check last consolidation date
MEMORY_FILE="$HOME/.savia-memory/auto/MEMORY.md"
LAST_CONSOLIDATION="unknown"
if [[ -f "$MEMORY_FILE" ]]; then
  LAST_CONSOLIDATION=$(grep -oP 'Última consolidación.*?\K\d{4}-\d{2}-\d{2}' "$MEMORY_FILE" 2>/dev/null || echo "unknown")
fi

DAYS_SINCE=999
if [[ "$LAST_CONSOLIDATION" != "unknown" ]]; then
  CONSOL_DATE=$(date -d "$LAST_CONSOLIDATION" +%s 2>/dev/null || echo 0)
  NOW=$(date +%s)
  DAYS_SINCE=$(( (NOW - CONSOL_DATE) / 86400 ))
fi

if [[ "$TOTAL" -ge "$THRESHOLD" ]] || [[ "$DAYS_SINCE" -ge 7 ]]; then
  echo "{\"triggered\":true,\"detector\":\"memory-consolidation\",\"total_entries\":$TOTAL,\"last_consolidation\":\"$LAST_CONSOLIDATION\",\"days_since\":$DAYS_SINCE,\"summary\":\"$TOTAL memory entries, last consolidated $DAYS_SINCE days ago\"}"
else
  echo "{\"triggered\":false,\"reason\":\"below threshold ($TOTAL < $THRESHOLD entries, $DAYS_SINCE days since consolidation)\"}"
fi
