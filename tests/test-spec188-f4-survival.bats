#!/usr/bin/env bats
# test-spec188-f4-survival.bats — SPEC-188 F4 tests
# Tests for Fix Survival Check and Monthly Diagnostic Report
# Run: bats tests/test-spec188-f4-survival.bats
# Ref: SPEC-188 F4 — docs/propuestas/SPEC-188-root-cause-investigation-architecture.md

setup() {
  REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel 2>/dev/null || pwd)"
  SURVIVAL_SCRIPT="${REPO_ROOT}/scripts/fix-survival-check.sh"
  MONTHLY_SCRIPT="${REPO_ROOT}/scripts/monthly-diagnostic-report.sh"
  REPORTS_DIR="${REPO_ROOT}/output/reports"
  TMPDIR_REPORTS="$(mktemp -d)"
  export CLAUDE_PROJECT_DIR="$REPO_ROOT"
}

teardown() {
  rm -rf "$TMPDIR_REPORTS"
}

# 1 — fix-survival-check.sh exists and is executable
@test "fix-survival-check.sh exists and is executable" {
  [ -f "$SURVIVAL_SCRIPT" ]
  [ -x "$SURVIVAL_SCRIPT" ]
}

# 2 — --json flag produces valid JSON
@test "fix-survival-check.sh --json produces valid JSON" {
  run bash "$SURVIVAL_SCRIPT" --json --days 7
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys, json; json.load(sys.stdin)"
}

# 3 — survival_rate is in [0, 1]
@test "fix-survival-check.sh survival_rate is in [0.0, 1.0]" {
  OUTPUT=$(bash "$SURVIVAL_SCRIPT" --json --days 7)
  python3 -c "
import sys, json
d = json.loads('''$OUTPUT''')
rate = d.get('survival_rate', -1)
assert 0.0 <= float(rate) <= 1.0, f'survival_rate {rate} not in [0,1]'
print('ok:', rate)
"
}

# 4 — JSON output contains all required fields
@test "fix-survival-check.sh JSON has required fields" {
  OUTPUT=$(bash "$SURVIVAL_SCRIPT" --json --days 7)
  python3 -c "
import sys, json
d = json.loads('''$OUTPUT''')
required = ['week', 'checked_at', 'days_back', 'fixes_total', 'fixes_survived', 'survival_rate', 'reverted']
missing = [k for k in required if k not in d]
if missing:
    print('Missing fields:', missing, file=sys.stderr)
    sys.exit(1)
print('all fields present')
"
}

# 5 — reverted field is a list
@test "fix-survival-check.sh reverted field is a JSON array" {
  OUTPUT=$(bash "$SURVIVAL_SCRIPT" --json --days 7)
  python3 -c "
import sys, json
d = json.loads('''$OUTPUT''')
assert isinstance(d.get('reverted'), list), 'reverted is not a list'
print('reverted is list, len:', len(d['reverted']))
"
}

# 6 — monthly-diagnostic-report.sh exists and is executable
@test "monthly-diagnostic-report.sh exists and is executable" {
  [ -f "$MONTHLY_SCRIPT" ]
  [ -x "$MONTHLY_SCRIPT" ]
}

# 7 — report is generated in output/reports/
@test "monthly-diagnostic-report.sh generates report in output/reports/" {
  TEST_MONTH="2026-06"
  run bash "$MONTHLY_SCRIPT" --month "$TEST_MONTH"
  [ "$status" -eq 0 ]
  [ -f "${REPORTS_DIR}/diagnostic-${TEST_MONTH}.md" ]
}

# 8 — generated report contains required sections
@test "monthly-diagnostic-report.sh report has required sections" {
  TEST_MONTH="2026-06"
  bash "$MONTHLY_SCRIPT" --month "$TEST_MONTH" >/dev/null 2>&1 || true
  REPORT="${REPORTS_DIR}/diagnostic-${TEST_MONTH}.md"
  [ -f "$REPORT" ]
  grep -qi "survival" "$REPORT"
  grep -qi "accuracy" "$REPORT"
  grep -q "SPEC-188" "$REPORT"
}

# 9 — fix-survival-check.sh handles zero commits gracefully
@test "fix-survival-check.sh handles zero fix commits (--days 0)" {
  run bash "$SURVIVAL_SCRIPT" --json --days 0
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['fixes_total'] >= 0
print('fixes_total:', d['fixes_total'])
"
}

# 10 — monthly report frontmatter contains month field
@test "monthly-diagnostic-report.sh report has valid frontmatter" {
  TEST_MONTH="2026-06"
  bash "$MONTHLY_SCRIPT" --month "$TEST_MONTH" >/dev/null 2>&1 || true
  REPORT="${REPORTS_DIR}/diagnostic-${TEST_MONTH}.md"
  [ -f "$REPORT" ]
  grep -q "month: ${TEST_MONTH}" "$REPORT"
  grep -q "report_type:" "$REPORT"
}
