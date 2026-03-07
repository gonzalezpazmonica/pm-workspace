#!/usr/bin/env bash
# audit-test-quality.sh — Classifies test scripts by quality level
# Levels:
#   L0 (scaffolding): only file existence checks (test -f, check_exists)
#   L1 (structural): checks file content with grep (check_content)
#   L2 (behavioral): runs commands, validates output, tests logic
#   L3 (integration): tests full workflows with setup/teardown
#
# Usage: bash scripts/audit-test-quality.sh [--summary | --detail | --csv]
set -uo pipefail

MODE="${1:---summary}"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL=0; L0=0; L1=0; L2=0; L3=0

classify() {
  local f="$1"
  local level=0
  local content
  content=$(cat "$f" 2>/dev/null || echo "")

  # L3 indicators: setup/teardown, temp dirs, process execution, subshells
  if echo "$content" | grep -qE '(setup\(\)|teardown\(\)|mktemp|BATS_|@test |run .*bash|\.bats)'; then
    level=3
  # L2 indicators: command execution, output capture, exit code checks
  elif echo "$content" | grep -qE '(output=.*\$\(|exit_code|assert_|run_hook|bash -c|eval |status.*-eq|actual.*expected)'; then
    level=2
  # L1 indicators: grep content checks
  elif echo "$content" | grep -qE '(grep -q|check_content|check_max_lines|wc -l)'; then
    level=1
  # L0: only file existence
  else
    level=0
  fi

  echo "$level"
}

declare -A LEVEL_FILES

for f in "$SCRIPTS_DIR"/test-*.sh; do
  [ -f "$f" ] || continue
  ((TOTAL++))
  level=$(classify "$f")
  case "$level" in
    0) ((L0++)) ;;
    1) ((L1++)) ;;
    2) ((L2++)) ;;
    3) ((L3++)) ;;
  esac
  LEVEL_FILES["$f"]="$level"
done

# Also check BATS tests
for f in "$(dirname "$SCRIPTS_DIR")"/tests/hooks/*.bats; do
  [ -f "$f" ] || continue
  ((TOTAL++))
  ((L3++))
  LEVEL_FILES["$f"]=3
done

case "$MODE" in
  --summary)
    echo "═══════════════════════════════════════════════════"
    echo "  📊 Test Quality Audit — pm-workspace"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "  Total test files: $TOTAL"
    echo ""
    echo "  L0 (scaffolding/existence): $L0 ($(( L0 * 100 / TOTAL ))%)"
    echo "  L1 (structural/content):    $L1 ($(( L1 * 100 / TOTAL ))%)"
    echo "  L2 (behavioral/logic):      $L2 ($(( L2 * 100 / TOTAL ))%)"
    echo "  L3 (integration/BATS):      $L3 ($(( L3 * 100 / TOTAL ))%)"
    echo ""
    REAL=$((L2 + L3))
    echo "  Real tests (L2+L3): $REAL / $TOTAL ($(( REAL * 100 / TOTAL ))%)"
    echo "  Target: ≥80% real tests"
    echo ""
    ;;
  --detail)
    for f in "${!LEVEL_FILES[@]}"; do
      echo "L${LEVEL_FILES[$f]}  $(basename "$f")"
    done | sort
    ;;
  --csv)
    echo "file,level,classification"
    for f in "${!LEVEL_FILES[@]}"; do
      local_level="${LEVEL_FILES[$f]}"
      case "$local_level" in
        0) class="scaffolding" ;;
        1) class="structural" ;;
        2) class="behavioral" ;;
        3) class="integration" ;;
      esac
      echo "$(basename "$f"),$local_level,$class"
    done | sort
    ;;
esac
