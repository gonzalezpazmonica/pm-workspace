#!/usr/bin/env bats
# tests/bats/test-se-040-canary.bats — SE-040 Agent Degradation Canary
# Tests for scripts/agent-degradation-canary.sh
#
# Ref: docs/propuestas/SE-040-agent-degradation-canary.md

SCRIPT="$(git rev-parse --show-toplevel)/scripts/agent-degradation-canary.sh"

# ── Test 1: Script exists and is parseable ────────────────────────────────────
@test "SE-040-01: script exists and is bash-parseable" {
  [ -f "$SCRIPT" ]
  bash -n "$SCRIPT"
}

# ── Test 2: Script runs successfully with all 3 canaries ─────────────────────
@test "SE-040-02: all 3 canaries pass (exit 0)" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Test 3: JSON output is valid and has required fields ──────────────────────
@test "SE-040-03: --json output is valid JSON with total, passed, failed, degraded" {
  run bash "$SCRIPT" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert 'total' in d
assert 'passed' in d
assert 'failed' in d
assert 'degraded' in d
assert d['total'] == 3
"
  [ $? -eq 0 ]
}

# ── Test 4: JSON shows total = 3 ─────────────────────────────────────────────
@test "SE-040-04: JSON output shows total of 3 canaries" {
  run bash "$SCRIPT" --json
  total=$(echo "$output" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['total'])")
  [ "$total" -eq 3 ]
}

# ── Test 5: passed = 3 when all canaries are healthy ─────────────────────────
@test "SE-040-05: JSON shows passed=3 when all canaries succeed" {
  run bash "$SCRIPT" --json
  passed=$(echo "$output" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['passed'])")
  [ "$passed" -eq 3 ]
}

# ── Test 6: degraded = false when all pass ───────────────────────────────────
@test "SE-040-06: degraded is false when all canaries pass" {
  run bash "$SCRIPT" --json
  # degraded should be JSON false (Python prints as 'False')
  degraded=$(echo "$output" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['degraded'])")
  [ "$degraded" = "False" ]
}

# ── Test 7: --quiet suppresses table but still produces JSON ─────────────────
@test "SE-040-07: --quiet mode still outputs JSON result" {
  run bash "$SCRIPT" --quiet
  # Output should be JSON line only
  echo "$output" | python3 -c "import json,sys; json.loads(sys.stdin.read())"
  [ $? -eq 0 ]
}

# ── Test 8: text output contains canary names ─────────────────────────────────
@test "SE-040-08: text output contains canary names" {
  run bash "$SCRIPT"
  [[ "$output" == *"router-mode-classifier"* ]]
  [[ "$output" == *"semantic-fault-handlers"* ]]
  [[ "$output" == *"glm-validate"* ]]
}
