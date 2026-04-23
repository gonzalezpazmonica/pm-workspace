#!/usr/bin/env bash
# hook-test-coverage-audit.sh — Detect hooks in .claude/hooks/ without BATS tests.
#
# Baseline ratchet: current untested count must not grow. New hooks must
# ship with tests OR be explicitly exempted (small libs, profile-gate, etc).
#
# Usage:
#   hook-test-coverage-audit.sh                # report
#   hook-test-coverage-audit.sh --json         # JSON output
#   hook-test-coverage-audit.sh --min-lines 50 # only flag hooks >= N lines
#
# Exit codes:
#   0 — coverage within baseline (no regression)
#   1 — regression (new untested hooks vs baseline)
#   2 — usage error
#
# Ref: batch 39 hook test coverage gap

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HOOKS_DIR="$PROJECT_ROOT/.claude/hooks"
TESTS_DIR="$PROJECT_ROOT/tests"
BASELINE_FILE="$PROJECT_ROOT/.ci-baseline/hook-untested-count.count"
MIN_LINES=0
JSON=0

# Hooks intentionally exempt (libraries, trivial wrappers, profile gates)
EXEMPT_PATTERNS=(
  "^lib/"
  "profile-gate"
  "-lib$"
)

usage() {
  cat <<EOF
Usage: $0 [--json] [--min-lines N]

Audits .claude/hooks/*.sh against tests/test-*.bats coverage. Emits count
of untested hooks and list. Compares against baseline to detect regression.

Options:
  --json            JSON output
  --min-lines N     Only count hooks >= N lines as violations (default 0)

Exempt patterns: ${EXEMPT_PATTERNS[*]}
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --min-lines) MIN_LINES="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown flag '$1'" >&2; exit 2 ;;
  esac
done

[[ ! -d "$HOOKS_DIR" ]] && { echo "ERROR: hooks dir not found: $HOOKS_DIR" >&2; exit 2; }
[[ ! -d "$TESTS_DIR" ]] && { echo "ERROR: tests dir not found: $TESTS_DIR" >&2; exit 2; }

is_exempt() {
  local name="$1"
  for pat in "${EXEMPT_PATTERNS[@]}"; do
    [[ "$name" =~ $pat ]] && return 0
  done
  return 1
}

UNTESTED=()
TESTED=0
EXEMPT=0
TOTAL=0

# Scan top-level hooks
for h in "$HOOKS_DIR"/*.sh; do
  [[ -f "$h" ]] || continue
  TOTAL=$((TOTAL + 1))
  b=$(basename "$h" .sh)
  if is_exempt "$b"; then
    EXEMPT=$((EXEMPT + 1))
    continue
  fi
  lines=$(wc -l <"$h")
  if [[ -f "$TESTS_DIR/test-$b.bats" ]]; then
    TESTED=$((TESTED + 1))
  else
    # Only count as violation if meets --min-lines threshold
    if [[ "$lines" -ge "$MIN_LINES" ]]; then
      UNTESTED+=("$b|$lines")
    fi
  fi
done

# Read baseline (default 999 if absent — first run)
BASELINE=999
[[ -f "$BASELINE_FILE" ]] && BASELINE=$(cat "$BASELINE_FILE" | tr -d '[:space:]')
BASELINE="${BASELINE:-999}"

COUNT="${#UNTESTED[@]}"

EXIT=0
[[ "$COUNT" -gt "$BASELINE" ]] && EXIT=1

if [[ "$JSON" -eq 1 ]]; then
  printf '{"verdict":"%s","total":%d,"tested":%d,"exempt":%d,"untested":%d,"baseline":%d,"min_lines":%d,"untested_list":[' \
    "$([ $EXIT -eq 0 ] && echo PASS || echo FAIL)" "$TOTAL" "$TESTED" "$EXEMPT" "$COUNT" "$BASELINE" "$MIN_LINES"
  sep=""
  for row in "${UNTESTED[@]}"; do
    IFS='|' read -r name lines <<< "$row"
    printf '%s{"hook":"%s","lines":%d}' "$sep" "$name" "$lines"
    sep=","
  done
  printf ']}\n'
else
  echo "=== Hook Test Coverage Audit ==="
  echo ""
  echo "Total hooks:      $TOTAL"
  echo "Tested:           $TESTED"
  echo "Exempt (libs):    $EXEMPT"
  echo "Untested:         $COUNT"
  echo "Baseline:         $BASELINE"
  echo "Min lines filter: $MIN_LINES"
  echo ""
  if [[ "$COUNT" -gt 0 ]]; then
    echo "Untested hooks (largest first):"
    for row in "${UNTESTED[@]}"; do
      IFS='|' read -r name lines <<< "$row"
      printf "  %4d lines  %s\n" "$lines" "$name"
    done | sort -rn
    echo ""
  fi
  echo "VERDICT: $([ $EXIT -eq 0 ] && echo PASS || echo FAIL)"
fi

exit $EXIT
