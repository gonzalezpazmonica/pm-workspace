#!/bin/bash
set -uo pipefail
# self-audit.sh — SE-258 Slice 3
# Orquestador de auto-auditoria con muestreo de regresion

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$REPO_ROOT/config/self-audit-battery.yaml"
START_TS=$(date +%s)
QUICK=false
SINGLE_CHECK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick) QUICK=true; shift ;;
    --check) SINGLE_CHECK="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: config/self-audit-battery.yaml not found" >&2
  exit 2
fi

echo "=== Savia Self-Audit — $(date +%Y-%m-%dT%H:%M:%S) ==="
echo ""

TOTAL=0
PASSED=0
FAILED=0
CRITICAL_FAILED=0
HIGH_FAILED=0

run_check() {
  local id="$1" script="$2" severity="$3" timeout_sec="$4" desc="$5"
  
  if [ "$QUICK" = true ] && [ "$severity" = "medium" ]; then
    printf "  SKIP [%s] %-30s (quick mode)\n" "$severity" "$id"
    return
  fi
  
  printf "  RUN  [%s] %-30s " "$severity" "$id"
  
  local check_start=$(date +%s)
  local result_output
  local exit_code=0
  
  if result_output=$(timeout "$timeout_sec" bash "$REPO_ROOT/$script" 2>&1); then
    exit_code=$?
  else
    exit_code=$?
  fi
  
  local check_end=$(date +%s)
  local duration=$((check_end - check_start))
  
  TOTAL=$((TOTAL + 1))
  
  if [ "$exit_code" -eq 0 ]; then
    echo "OK (${duration}s)"
    PASSED=$((PASSED + 1))
  elif [ "$exit_code" -eq 124 ]; then
    echo "TIMEOUT (${duration}s)"
    FAILED=$((FAILED + 1))
    [ "$severity" = "critical" ] && CRITICAL_FAILED=$((CRITICAL_FAILED + 1))
  else
    echo "FAIL (${duration}s)"
    FAILED=$((FAILED + 1))
    [ "$severity" = "critical" ] && CRITICAL_FAILED=$((CRITICAL_FAILED + 1))
    [ "$severity" = "high" ] && HIGH_FAILED=$((HIGH_FAILED + 1))
    if [ -n "$result_output" ]; then
      echo "        $(echo "$result_output" | head -3 | tr '\n' ' ')"
    fi
  fi
}

echo "--- Checks ---"
while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*-[[:space:]]*id: ]] || continue
  
  id=$(echo "$line" | sed 's/.*id:[[:space:]]*"\(.*\)"/\1/')
  
  if [ -n "$SINGLE_CHECK" ] && [ "$id" != "$SINGLE_CHECK" ]; then
    continue
  fi
  
  IFS= read -r script_line; IFS= read -r desc_line; IFS= read -r sev_line; IFS= read -r timeout_line
  
  script=$(echo "$script_line" | sed 's/.*script:[[:space:]]*"\(.*\)"/\1/')
  severity=$(echo "$sev_line" | sed 's/.*severity:[[:space:]]*"\(.*\)"/\1/')
  timeout_sec=$(echo "$timeout_line" | sed 's/.*timeout:[[:space:]]*\([0-9]*\)/\1/')
  desc=$(echo "$desc_line" | sed 's/.*description:[[:space:]]*"\(.*\)"/\1/')
  
  run_check "$id" "$script" "$severity" "$timeout_sec" "$desc"
done < "$CONFIG"

echo ""
echo "--- Regression Sampling ---"
SAMPLING_ENABLED=$(grep -A1 '^sampling:' "$CONFIG" | grep 'enabled:' | grep -o 'true\|false')
if [ "$SAMPLING_ENABLED" = "true" ] && [ "$QUICK" = false ]; then
  ARCHIVE_DIR=$(grep 'archive_dir:' "$CONFIG" | sed 's/.*archive_dir:[[:space:]]*"\(.*\)"/\1/')
  SAMPLE_COUNT=$(grep 'count:' "$CONFIG" | sed 's/.*count:[[:space:]]*\([0-9]*\)/\1/')
  
  if [ -d "$REPO_ROOT/$ARCHIVE_DIR" ]; then
    mapfile -t SPECS < <(find "$REPO_ROOT/$ARCHIVE_DIR" -name "*.md" -type f 2>/dev/null | shuf -n "$SAMPLE_COUNT" 2>/dev/null)
    
    if [ ${#SPECS[@]} -gt 0 ]; then
      for spec in "${SPECS[@]}"; do
        spec_name=$(basename "$spec")
        echo "  SAMPLE: $spec_name"
        grep -q 'DONE\|APPROVED\|IMPLEMENTADO' "$spec" 2>/dev/null && echo "    status tags: found" || echo "    status tags: missing or unclear"
      done
    else
      echo "  No specs found in $ARCHIVE_DIR"
    fi
  fi
else
  echo "  Skipped (sampling disabled or quick mode)"
fi

END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))

echo ""
echo "=== Summary ==="
echo "Total checks:   $TOTAL"
echo "Passed:         $PASSED"
echo "Failed:         $FAILED"
echo "Critical fails: $CRITICAL_FAILED"
echo "High fails:     $HIGH_FAILED"
echo "Duration:       ${DURATION}s"

if [ "$CRITICAL_FAILED" -gt 0 ]; then
  echo ""
  echo "RESULT: FAIL ($CRITICAL_FAILED critical check(s) failed)"
  exit 1
fi

echo ""
echo "RESULT: PASS"
exit 0
