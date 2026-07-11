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
  local id="$1" script="$2" severity="$3" timeout_sec="$4"

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

# ── Parse YAML with state machine ──
echo "--- Checks ---"
IN_BATTERY=0
CURRENT_ID=""
CURRENT_SCRIPT=""
CURRENT_SEVERITY=""
CURRENT_TIMEOUT=""
CURRENT_DESC=""

flush_entry() {
  [[ -z "$CURRENT_ID" ]] && return
  if [[ -n "$SINGLE_CHECK" ]] && [[ "$CURRENT_ID" != "$SINGLE_CHECK" ]]; then
    CURRENT_ID=""; CURRENT_SCRIPT=""; CURRENT_SEVERITY=""; CURRENT_TIMEOUT=""; CURRENT_DESC=""
    return
  fi
  run_check "$CURRENT_ID" "$CURRENT_SCRIPT" "$CURRENT_SEVERITY" "$CURRENT_TIMEOUT"
  CURRENT_ID=""; CURRENT_SCRIPT=""; CURRENT_SEVERITY=""; CURRENT_TIMEOUT=""; CURRENT_DESC=""
}

while IFS= read -r line; do
  [[ "$line" =~ ^battery: ]] && { IN_BATTERY=1; continue; }
  [[ "$IN_BATTERY" -eq 0 ]] && continue

  # Section boundary: non-indented key ends battery
  if [[ "$line" =~ ^[a-z] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
    flush_entry
    IN_BATTERY=0
    continue
  fi

  # New entry: "- id:"
  if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*id: ]]; then
    flush_entry
    CURRENT_ID=$(echo "$line" | sed 's/.*id:[[:space:]]*"\(.*\)"/\1/')
    continue
  fi

  [[ -z "$CURRENT_ID" ]] && continue

  if [[ "$line" =~ ^[[:space:]]*script: ]]; then
    CURRENT_SCRIPT=$(echo "$line" | sed 's/.*script:[[:space:]]*"\(.*\)"/\1/')
  elif [[ "$line" =~ ^[[:space:]]*severity: ]]; then
    CURRENT_SEVERITY=$(echo "$line" | sed 's/.*severity:[[:space:]]*"\(.*\)"/\1/')
  elif [[ "$line" =~ ^[[:space:]]*timeout: ]]; then
    CURRENT_TIMEOUT=$(echo "$line" | sed 's/.*timeout:[[:space:]]*\([0-9]*\)/\1/')
  elif [[ "$line" =~ ^[[:space:]]*description: ]]; then
    CURRENT_DESC=$(echo "$line" | sed 's/.*description:[[:space:]]*"\(.*\)"/\1/')
  fi
done < "$CONFIG"
flush_entry

echo ""
echo "--- Regression Sampling ---"
SAMPLING_ENABLED=$(grep -A1 '^sampling:' "$CONFIG" | grep 'enabled:' | grep -o 'true\|false')
SAMPLE_COUNT=$(grep 'count:' "$CONFIG" | head -1 | sed 's/.*count:[[:space:]]*\([0-9]*\)/\1/')
ARCHIVE_DIR=$(grep 'archive_dir:' "$CONFIG" | sed 's/.*archive_dir:[[:space:]]*"\(.*\)"/\1/')

if [ "${SAMPLING_ENABLED:-false}" = "true" ] && [ "$QUICK" = false ]; then
  SAMPLE_COUNT="${SAMPLE_COUNT:-3}"
  if [ -d "$REPO_ROOT/$ARCHIVE_DIR" ]; then
    mapfile -t SPECS < <(find "$REPO_ROOT/$ARCHIVE_DIR" -name "*.md" -type f 2>/dev/null | shuf -n "$SAMPLE_COUNT" 2>/dev/null || true)

    if [ ${#SPECS[@]} -gt 0 ]; then
      for spec in "${SPECS[@]}"; do
        spec_name=$(basename "$spec")
        echo "  SAMPLE: $spec_name"

        # Count slices with explicit status
        slice_count=$(grep -cE '^\| S[0-9]' "$spec" 2>/dev/null || true)
        done_count=$(grep -cE '^\| S[0-9].*\|.*DONE' "$spec" 2>/dev/null || true)
        pending_count=$(grep -cE '^\| S[0-9].*\|.*PENDING' "$spec" 2>/dev/null || true)
        abandoned_count=$(grep -cE '^\| S[0-9].*\|.*ABANDONED' "$spec" 2>/dev/null || true)

        if [ "${slice_count:-0}" -gt 0 ]; then
          echo "    slices: ${slice_count} (${done_count:-0} DONE, ${pending_count:-0} PENDING, ${abandoned_count:-0} ABANDONED)"
        else
          # Old-style spec without slice table: check for status words
          status_tags=""
          grep -q 'DONE\|APPROVED\|IMPLEMENTADO\|MERGED' "$spec" 2>/dev/null && status_tags="${status_tags}done "
          grep -q 'PENDING\|PROPOSED\|IN_PROGRESS' "$spec" 2>/dev/null && status_tags="${status_tags}pending "
          grep -q 'ABANDONED\|REJECTED\|OBSOLETO' "$spec" 2>/dev/null && status_tags="${status_tags}abandoned "
          echo "    status tags: ${status_tags:-none}"
        fi
      done
    else
      echo "  No specs found in $ARCHIVE_DIR"
    fi
  else
    echo "  Archive dir $ARCHIVE_DIR not found"
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
