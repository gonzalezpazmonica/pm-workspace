#!/usr/bin/env bats
# test-se-024-client-health.bats — SE-024 Client Health Intelligence
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-024-client-health.md

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export REPO_ROOT

  HEALTH_SCORE="${REPO_ROOT}/scripts/enterprise/client-health-score.sh"
  HEALTH_REPORT="${REPO_ROOT}/scripts/enterprise/client-health-report.sh"
  export HEALTH_SCORE HEALTH_REPORT

  # Create minimal tenant/client structure for testing
  mkdir -p "${TEST_TMPDIR}/tenants/test-tenant/clients/test-client"
  export TEST_TENANT="test-tenant"
  export TEST_CLIENT="test-client"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Test 1: client-health-score.sh exists and produces JSON ──────────────────

@test "client-health-score.sh exists and is executable" {
  [[ -f "$HEALTH_SCORE" ]]
  [[ -x "$HEALTH_SCORE" ]]
}

# ── Test 2: produces JSON with score field ────────────────────────────────────

@test "client-health-score.sh produces JSON with score field" {
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' '$HEALTH_SCORE' --client '$TEST_CLIENT' --tenant '$TEST_TENANT' --json"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"score"'
}

# ── Test 3: score is between 0 and 100 ───────────────────────────────────────

@test "client-health-score.sh score is in range [0, 100]" {
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' '$HEALTH_SCORE' --client '$TEST_CLIENT' --tenant '$TEST_TENANT' --json"
  [ "$status" -eq 0 ]

  # Extract score value
  SCORE="$(echo "$output" | grep '"score"' | grep -o '[0-9]*' | head -1)"
  [[ -n "$SCORE" ]]
  (( SCORE >= 0 && SCORE <= 100 ))
}

# ── Test 4: dimensions object has at least 4 keys ────────────────────────────

@test "client-health-score.sh dimensions object has at least 4 keys" {
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' '$HEALTH_SCORE' --client '$TEST_CLIENT' --tenant '$TEST_TENANT' --json"
  [ "$status" -eq 0 ]

  echo "$output" | grep -q '"dimensions"'

  # Count dimension entries (each has "score" key inside)
  DIM_COUNT="$(echo "$output" | grep -c '"score":' || true)"
  # 1 top-level score + at least 4 dimension scores
  (( DIM_COUNT >= 5 ))
}

# ── Test 5: risk field is one of the valid values ─────────────────────────────

@test "client-health-score.sh risk field is low|medium|high|critical" {
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' '$HEALTH_SCORE' --client '$TEST_CLIENT' --tenant '$TEST_TENANT' --json"
  [ "$status" -eq 0 ]

  RISK="$(echo "$output" | grep '"risk"' | cut -d'"' -f4)"
  [[ "$RISK" == "low" || "$RISK" == "medium" || "$RISK" == "high" || "$RISK" == "critical" ]]
}

# ── Test 6: client-health-report.sh with empty tenant is graceful ─────────────

@test "client-health-report.sh with empty tenant does not fail" {
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' '$HEALTH_REPORT' --tenant 'empty-tenant'"
  # Should exit 0 (graceful empty output)
  [ "$status" -eq 0 ]
}

# ── Test 7: client-health-report.sh exists and is executable ─────────────────

@test "client-health-report.sh exists and is executable" {
  [[ -f "$HEALTH_REPORT" ]]
  [[ -x "$HEALTH_REPORT" ]]
}
