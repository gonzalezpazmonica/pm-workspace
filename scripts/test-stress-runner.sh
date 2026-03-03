#!/usr/bin/env bash
# ── test-stress-runner.sh — Orchestrator for all stress tests ──
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts"
OUTPUT_DIR="$REPO_ROOT/output/test-results"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT="$OUTPUT_DIR/stress-$TIMESTAMP.txt"

TOTAL_PASS=0; TOTAL_FAIL=0; SUITES_PASS=0; SUITES_FAIL=0

echo "═══════════════════════════════════════════════════════════"
echo "  🧪 PM-Workspace Stress Test Runner"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "═══════════════════════════════════════════════════════════"
echo "" | tee "$REPORT"

run_suite() {
  local name="$1" script="$2"
  echo "──────────────────────────────────────────────────────" | tee -a "$REPORT"
  echo "  ▶ $name" | tee -a "$REPORT"
  echo "──────────────────────────────────────────────────────" | tee -a "$REPORT"
  local exit_code=0
  bash "$script" 2>&1 | tee -a "$REPORT" || exit_code=$?
  # Extract counts from last Total line
  local last_line; last_line=$(grep "Total:" "$REPORT" | tail -1)
  local p; p=$(echo "$last_line" | grep -oP 'Passed: \K[0-9]+' || echo 0)
  local f; f=$(echo "$last_line" | grep -oP 'Failed: \K[0-9]+' || echo 0)
  TOTAL_PASS=$((TOTAL_PASS + p))
  TOTAL_FAIL=$((TOTAL_FAIL + f))
  if [ "$exit_code" -eq 0 ]; then
    SUITES_PASS=$((SUITES_PASS + 1))
  else
    SUITES_FAIL=$((SUITES_FAIL + 1))
  fi
  echo "" | tee -a "$REPORT"
}

# ── New stress test suites ──────────────────────────────────
run_suite "Stress Hooks" "$SCRIPTS_DIR/test-stress-hooks.sh"
run_suite "Stress Security" "$SCRIPTS_DIR/test-stress-security.sh"
run_suite "Stress Scripts" "$SCRIPTS_DIR/test-stress-scripts.sh"
run_suite "Era 18 Commands" "$SCRIPTS_DIR/test-era18-commands.sh"
run_suite "Era 18 Rules" "$SCRIPTS_DIR/test-era18-rules.sh"
run_suite "Era 18 Formulas" "$SCRIPTS_DIR/test-era18-formulas.sh"

# ── Existing test suites ────────────────────────────────────
run_suite "E2E Harness" "$SCRIPTS_DIR/test-savia-e2e-harness.sh"
run_suite "CI Local" "$SCRIPTS_DIR/validate-ci-local.sh"
run_suite "Command Validation" "$SCRIPTS_DIR/validate-commands.sh"

# ── Summary ─────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════" | tee -a "$REPORT"
echo "  📊 STRESS TEST SUMMARY" | tee -a "$REPORT"
echo "═══════════════════════════════════════════════════════════" | tee -a "$REPORT"
echo "  Suites: $((SUITES_PASS+SUITES_FAIL)) | ✅ $SUITES_PASS | ❌ $SUITES_FAIL" | tee -a "$REPORT"
echo "  Tests:  $((TOTAL_PASS+TOTAL_FAIL)) | ✅ $TOTAL_PASS | ❌ $TOTAL_FAIL" | tee -a "$REPORT"
echo "  Report: $REPORT" | tee -a "$REPORT"
echo "═══════════════════════════════════════════════════════════" | tee -a "$REPORT"

if [ "$TOTAL_FAIL" -gt 0 ]; then
  echo "  ⚠️  SOME TESTS FAILED" | tee -a "$REPORT"
  exit 1
fi
echo "  🎉 ALL TESTS PASSED" | tee -a "$REPORT"
exit 0
