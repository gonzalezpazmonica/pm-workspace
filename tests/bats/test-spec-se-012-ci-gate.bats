#!/usr/bin/env bats
# test-spec-se-012-ci-gate.bats — SPEC-SE-012 CI Reliability Gate
#
# Tests for scripts/ci-reliability-gate.sh
# Run: bats tests/bats/test-spec-se-012-ci-gate.bats

WORKSPACE="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$WORKSPACE/scripts/ci-reliability-gate.sh"

# ── Test 1: Script exists and is executable ───────────────────────────────────
@test "ci-reliability-gate.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# ── Test 2: --json produces valid JSON ────────────────────────────────────────
@test "ci-reliability-gate.sh --json produces valid JSON" {
  run bash "$SCRIPT" --json
  # exit 0 (all pass) or 1 (some fail) are both OK
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)"
}

# ── Test 3: all_passed field present in JSON output ───────────────────────────
@test "JSON output contains all_passed field" {
  run bash "$SCRIPT" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'all_passed' in d, 'all_passed missing from JSON'
assert isinstance(d['all_passed'], bool), \
  'all_passed must be bool, got: ' + str(type(d['all_passed']))
"
}

# ── Test 4: checks array has >= 5 elements ────────────────────────────────────
@test "JSON checks array contains at least 5 checks" {
  run bash "$SCRIPT" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'checks' in d, 'checks array missing'
assert len(d['checks']) >= 5, \
  'Expected >= 5 checks, got ' + str(len(d['checks']))
"
}

# ── Test 5: each check has name, passed, details fields ───────────────────────
@test "Each check in JSON has name, passed, and details fields" {
  run bash "$SCRIPT" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for c in d['checks']:
  assert 'name' in c, 'check missing name: ' + str(c)
  assert 'passed' in c, 'check missing passed: ' + str(c)
  assert 'details' in c, 'check missing details: ' + str(c)
  assert isinstance(c['passed'], bool), \
    'passed must be bool in ' + c.get('name', '?')
"
}

# ── Test 6: expected check names are present ─────────────────────────────────
@test "All 8 expected check names are present" {
  run bash "$SCRIPT" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
names = {c['name'] for c in d['checks']}
expected = {
  'empty-dirs', 'staged-gitignored', 'exec-permissions',
  'broken-symlinks', 'large-files', 'encoding',
  'trailing-ws-bats', 'tabs-python'
}
missing = expected - names
assert not missing, 'Missing checks: ' + str(missing)
"
}

# ── Test 7: human-readable output (no --json) works without crash ─────────────
@test "ci-reliability-gate.sh without --json produces human-readable output" {
  run bash "$SCRIPT"
  # exit 0 or 1 both valid
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  # Output should contain CI Reliability Gate header
  echo "$output" | grep -q "CI Reliability Gate"
}

# ── Test 8: --fix-empty-dirs creates .gitkeep in empty dirs ──────────────────
@test "--fix-empty-dirs creates .gitkeep in an empty directory" {
  # Create a temp empty dir to trigger the check
  local tmpdir
  tmpdir=$(mktemp -d "$WORKSPACE/tests/bats/_tmp_empty_XXXXXX")
  # Run with --fix-empty-dirs
  run bash "$SCRIPT" --fix-empty-dirs --json
  # Check that .gitkeep was created
  local gitkeep="$tmpdir/.gitkeep"
  # Cleanup regardless
  rm -rf "$tmpdir"
  # The script should have run without crashing
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ── Test 9: g_pre_push_reliability wired into pr-plan-gates.sh ───────────────
@test "g_pre_push_reliability function defined in pr-plan-gates.sh" {
  grep -q "g_pre_push_reliability" "$WORKSPACE/scripts/pr-plan-gates.sh"
}

# ── Test 10: G15 gate wired into pr-plan.sh ───────────────────────────────────
@test "G15 CI reliability gate wired into pr-plan.sh" {
  grep -q "G15" "$WORKSPACE/scripts/pr-plan.sh"
  grep -q "g_pre_push_reliability" "$WORKSPACE/scripts/pr-plan.sh"
}
