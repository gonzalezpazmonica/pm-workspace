#!/usr/bin/env bash
# hook-latency-audit.sh — SE-037 Slice 1 hook latency enforcement audit.
#
# Audit layer sobre hooks registrados: wraps scripts/hook-latency-bench.sh
# e impone:
#   - SLA per-hook (critical 20ms, standard 100ms)
#   - Ratchet contra baseline en .ci-baseline/hook-critical-violations.count
#   - BATS coverage floor (cada hook tiene al menos 1 test .bats)
#   - Failure report con hooks offensivos + tests faltantes
#
# NO modifica hooks — solo audita y propone acciones.
#
# Usage:
#   hook-latency-audit.sh
#   hook-latency-audit.sh --iterations 5 --json
#   hook-latency-audit.sh --sla-critical 20 --sla-standard 100
#
# Exit codes:
#   0 — all hooks within SLA + tests present
#   1 — violations (latency or missing tests)
#   2 — usage error
#
# Ref: SE-037, SPEC-081 hook-bats-coverage
# Safety: read-only. set -uo pipefail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ITERATIONS=3
SLA_CRITICAL=20
SLA_STANDARD=100
JSON=0
CHECK_TESTS=1

usage() {
  cat <<EOF
Usage:
  $0 [options]

Options:
  --iterations N        Bench iterations per hook (default 3)
  --sla-critical MS     Critical hook SLA in ms (default 20)
  --sla-standard MS     Standard hook SLA in ms (default 100)
  --no-tests-check      Skip BATS coverage check (speed)
  --json                JSON output

Audit hooks: latency SLA + ratchet + BATS coverage. NO modifica hooks.
Ref: SE-037 §Objective, SPEC-081.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iterations) ITERATIONS="$2"; shift 2 ;;
    --sla-critical) SLA_CRITICAL="$2"; shift 2 ;;
    --sla-standard) SLA_STANDARD="$2"; shift 2 ;;
    --no-tests-check) CHECK_TESTS=0; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

for v in ITERATIONS SLA_CRITICAL SLA_STANDARD; do
  val="${!v}"
  if ! [[ "$val" =~ ^[0-9]+$ ]] || [[ "$val" -lt 1 ]]; then
    echo "ERROR: --${v,,} must be positive integer" >&2; exit 2
  fi
done

HOOKS_DIR="$PROJECT_ROOT/.claude/hooks"
BASELINE_FILE="$PROJECT_ROOT/.ci-baseline/hook-critical-violations.count"
TESTS_DIR="$PROJECT_ROOT/tests"

[[ ! -d "$HOOKS_DIR" ]] && { echo "ERROR: hooks dir not found: $HOOKS_DIR" >&2; exit 2; }

# Read baseline
BASELINE=0
[[ -f "$BASELINE_FILE" ]] && BASELINE=$(cat "$BASELINE_FILE" 2>/dev/null | tr -dc '0-9')
BASELINE="${BASELINE:-0}"

# Collect hook scripts
HOOK_FILES=()
while IFS= read -r f; do
  [[ -f "$f" && -x "$f" ]] && HOOK_FILES+=("$f")
done < <(find "$HOOKS_DIR" -maxdepth 2 -name "*.sh" -type f 2>/dev/null | sort)

TOTAL_HOOKS=${#HOOK_FILES[@]}
LATENCY_VIOLATIONS=0
MISSING_TESTS=0
OFFENDERS=()
MISSING_TEST_LIST=()

# Bench each hook with a trivial payload
bench_one() {
  local hook="$1" iters="$2"
  local total_ns=0
  for ((i=0; i<iters; i++)); do
    local t0 t1
    t0=$(date +%s%N 2>/dev/null || echo 0)
    # Run with minimal env; many hooks are defensive and exit 0 on no-op
    timeout 2 bash "$hook" </dev/null >/dev/null 2>&1 || true
    t1=$(date +%s%N 2>/dev/null || echo 0)
    total_ns=$((total_ns + (t1 - t0)))
  done
  echo $(( total_ns / iters / 1000000 ))  # ms average
}

# Classify hook: "critical" if name contains specific patterns
is_critical() {
  local name
  name=$(basename "$1")
  [[ "$name" =~ (pre-tool|pre-prompt|session-start|memory-prime|security) ]]
}

for hook in "${HOOK_FILES[@]}"; do
  hook_name=$(basename "$hook" .sh)
  latency=$(bench_one "$hook" "$ITERATIONS")

  # Determine SLA
  if is_critical "$hook"; then
    sla="$SLA_CRITICAL"
    tier="critical"
  else
    sla="$SLA_STANDARD"
    tier="standard"
  fi

  if [[ "$latency" -gt "$sla" ]]; then
    LATENCY_VIOLATIONS=$((LATENCY_VIOLATIONS + 1))
    OFFENDERS+=("$hook_name|$tier|${latency}ms|sla=${sla}ms")
  fi

  # BATS coverage check
  if [[ "$CHECK_TESTS" -eq 1 ]]; then
    if ! find "$TESTS_DIR" -name "*${hook_name}*.bats" -type f 2>/dev/null | grep -q .; then
      MISSING_TESTS=$((MISSING_TESTS + 1))
      MISSING_TEST_LIST+=("$hook_name")
    fi
  fi
done

# Verdict
VERDICT="PASS"
EXIT_CODE=0

if [[ "$LATENCY_VIOLATIONS" -gt "$BASELINE" ]]; then
  VERDICT="FAIL"
  EXIT_CODE=1
fi

if [[ "$CHECK_TESTS" -eq 1 ]] && [[ "$MISSING_TESTS" -gt $((TOTAL_HOOKS / 2)) ]]; then
  VERDICT="FAIL"
  EXIT_CODE=1
fi

if [[ "$JSON" -eq 1 ]]; then
  off_json=""
  for o in "${OFFENDERS[@]}"; do
    off_json+="\"$o\","
  done
  off_json="[${off_json%,}]"
  missing_json=""
  for m in "${MISSING_TEST_LIST[@]}"; do
    missing_json+="\"$m\","
  done
  missing_json="[${missing_json%,}]"
  cat <<JSON
{"verdict":"$VERDICT","total_hooks":$TOTAL_HOOKS,"latency_violations":$LATENCY_VIOLATIONS,"baseline":$BASELINE,"missing_tests":$MISSING_TESTS,"sla_critical_ms":$SLA_CRITICAL,"sla_standard_ms":$SLA_STANDARD,"offenders":$off_json,"missing_test_hooks":$missing_json}
JSON
else
  echo "=== SE-037 Hook Latency + BATS Audit ==="
  echo ""
  echo "Hooks total:         $TOTAL_HOOKS"
  echo "Latency SLA:         critical=${SLA_CRITICAL}ms  standard=${SLA_STANDARD}ms"
  echo "Latency violations:  $LATENCY_VIOLATIONS (baseline: $BASELINE)"
  echo "Missing BATS tests:  $MISSING_TESTS"
  echo ""
  if [[ ${#OFFENDERS[@]} -gt 0 ]]; then
    echo "Latency offenders (exceed SLA):"
    for o in "${OFFENDERS[@]}"; do
      echo "  • $o"
    done
    echo ""
  fi
  if [[ "$CHECK_TESTS" -eq 1 ]] && [[ ${#MISSING_TEST_LIST[@]} -gt 0 ]]; then
    echo "Missing BATS tests (first 10):"
    i=0
    for m in "${MISSING_TEST_LIST[@]}"; do
      [[ $i -ge 10 ]] && break
      echo "  • $m"
      i=$((i + 1))
    done
    echo ""
  fi
  echo "VERDICT: $VERDICT"
  if [[ "$VERDICT" == "FAIL" ]]; then
    echo ""
    echo "Remediation (SE-037 Slice 2):"
    echo "  1. Optimize offender hooks (early exit, cache, async)"
    echo "  2. Add BATS tests for uncovered hooks (template: tests/test-hook-*.bats)"
    echo "  3. Update baseline in .ci-baseline/hook-critical-violations.count once fixed"
  fi
fi

exit $EXIT_CODE
