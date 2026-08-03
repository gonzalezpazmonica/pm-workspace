#!/usr/bin/env bash
set -euo pipefail
# tabular-summarize.sh — Detect + extract + summarize tabular data
# SE-296: Pre-LLM wrapper that profiles data before it reaches the LLM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILER="$SCRIPT_DIR/tabular-profile.py"
INPUT="${1:--}"

if [[ ! -f "$PROFILER" ]]; then
  echo "ERROR: tabular-profile.py not found at $PROFILER" >&2
  exit 2
fi

# Check if input has tabular data (>5 lines of structured data)
detect_tabular() {
  local content="$1"
  local lines
  lines=$(echo "$content" | grep -cE '^\s*\|.+\|' || true)
  if [[ "$lines" -ge 5 ]]; then return 0; fi
  lines=$(echo "$content" | grep -c ',' || true)
  if [[ "$lines" -ge 6 ]]; then return 0; fi
  return 1
}

if [[ "$INPUT" == "-" ]]; then
  INPUT_DATA=$(cat)
else
  INPUT_DATA=$(cat "$INPUT" 2>/dev/null || echo "")
fi

if detect_tabular "$INPUT_DATA"; then
  echo "$INPUT_DATA" | python3 "$PROFILER" 2>/dev/null || {
    echo '{"error":"profiling failed","fallback":"raw"}'
  }
else
  echo '{"detected":false,"reason":"no tabular data found"}'
fi
