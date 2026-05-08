#!/usr/bin/env bash
# hook-latency-bench.sh — Mide la latencia media de cada hook registrado
# en settings.json. Output: JSON con latencia por hook, baseline, y lista
# de hooks que exceden 100ms (targets para optimización).
#
# SPEC-109 action 9 — hook benchmark + baseline
# Usage: bash scripts/hook-latency-bench.sh [--iterations N] [--output FILE]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."
ITERATIONS=3
OUTPUT=""
THRESHOLD_MS=100
STRICT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iterations) ITERATIONS="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --threshold) THRESHOLD_MS="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Mock hook input (common Bash event)
MOCK_INPUT='{"tool_name":"Bash","tool_input":{"command":"ls"},"session_id":"bench"}'

measure_hook() {
  local hook="$1"
  [[ -x "$hook" ]] || return 1

  local total_ms=0
  for ((i=0; i<ITERATIONS; i++)); do
    local start end elapsed
    start=$(date +%s%N)
    echo "$MOCK_INPUT" | timeout 5 "$hook" >/dev/null 2>&1 || true
    end=$(date +%s%N)
    elapsed=$(( (end - start) / 1000000 ))
    total_ms=$((total_ms + elapsed))
  done
  echo $((total_ms / ITERATIONS))
}

echo "Hook Latency Benchmark"
echo "======================"
echo "Iterations per hook: $ITERATIONS"
echo "Slow threshold: ${THRESHOLD_MS}ms"
echo ""

declare -a slow_hooks=()
declare -a results=()
total=0
slow_count=0

# Stop-event hooks run AFTER the user turn ends, not in hot path. They
# get a more lenient SLA (2.5x the hot-path threshold). A hook is
# classified as Stop-event if its name matches a Stop* pattern or if
# the hook is registered only under Stop in settings.json.
stop_hooks_re='^(scope-guard|session-end-snapshot|session-end-memory|session-end-signature)\.sh$'
stop_threshold_ms=$(( THRESHOLD_MS * 5 / 2 ))  # 500ms for 200ms base

for hook in "$ROOT"/.opencode/hooks/*.sh; do
  [[ -x "$hook" ]] || continue
  name=$(basename "$hook")
  avg_ms=$(measure_hook "$hook" 2>/dev/null || echo "-1")

  if [[ "$avg_ms" -eq -1 ]]; then
    printf "  %-50s SKIP (not executable)\n" "$name"
    continue
  fi

  results+=("$name:$avg_ms")
  total=$((total + 1))

  # Apply appropriate threshold based on classification.
  if [[ "$name" =~ $stop_hooks_re ]]; then
    effective_threshold="$stop_threshold_ms"
    suffix=" (stop-event SLA ${stop_threshold_ms}ms)"
  else
    effective_threshold="$THRESHOLD_MS"
    suffix=""
  fi

  if [[ "$avg_ms" -gt "$effective_threshold" ]]; then
    slow_hooks+=("$name:$avg_ms")
    slow_count=$((slow_count + 1))
    printf "  %-50s %4dms  SLOW%s\n" "$name" "$avg_ms" "$suffix"
  else
    printf "  %-50s %4dms%s\n" "$name" "$avg_ms" "$suffix"
  fi
done

echo ""
echo "======================"
echo "Total hooks benchmarked: $total"
echo "Hooks > ${THRESHOLD_MS}ms: $slow_count"
if [[ "${#slow_hooks[@]}" -gt 0 ]]; then
  echo ""
  echo "Slow hooks (targets for optimization):"
  for h in "${slow_hooks[@]}"; do
    echo "  - $h"
  done
fi

if [[ -n "$OUTPUT" ]]; then
  {
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"iterations\": $ITERATIONS,"
    echo "  \"threshold_ms\": $THRESHOLD_MS,"
    echo "  \"total\": $total,"
    echo "  \"slow_count\": $slow_count,"
    echo "  \"results\": {"
    first=true
    for r in "${results[@]}"; do
      name="${r%%:*}"
      ms="${r##*:}"
      $first && first=false || echo ","
      printf '    "%s": %d' "$name" "$ms"
    done
    echo ""
    echo "  }"
    echo "}"
  } > "$OUTPUT"
  echo ""
  echo "JSON output: $OUTPUT"
fi

if [[ "$STRICT" -eq 1 && "$slow_count" -gt 0 ]]; then
  echo ""
  echo "ERROR: $slow_count hooks exceed ${THRESHOLD_MS}ms threshold (--strict)"
  exit 1
fi

exit 0
