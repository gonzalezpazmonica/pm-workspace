#!/usr/bin/env bats
# test-se-008-licensing.bats — SPEC-SE-008 Licensing & Distribution
# Tests for license-generator.sh, commercial-terms-check.sh, enterprise-licensing-policy.md
# Reference: docs/propuestas/savia-enterprise/SPEC-SE-008-licensing-distribution.md

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export REPO_ROOT

  LICENSE_GEN="${REPO_ROOT}/scripts/enterprise/license-generator.sh"
  TERMS_CHECK="${REPO_ROOT}/scripts/enterprise/commercial-terms-check.sh"
  LICENSING_POLICY="${REPO_ROOT}/docs/rules/domain/enterprise-licensing-policy.md"
  export LICENSE_GEN TERMS_CHECK LICENSING_POLICY
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Test 1: license-generator.sh exists and is executable ────────────────────

@test "license-generator.sh exists and is executable" {
  [[ -f "$LICENSE_GEN" ]]
  [[ -x "$LICENSE_GEN" ]]
}

# ── Test 2: license-generator.sh produces LICENSE.md ─────────────────────────

@test "license-generator.sh produces LICENSE.md in output dir" {
  run "$LICENSE_GEN" --component "savia-test-component" --output-dir "$TEST_TMPDIR"
  [ "$status" -eq 0 ]
  [[ -f "${TEST_TMPDIR}/LICENSE.md" ]]
}

# ── Test 3: generated LICENSE.md contains MIT text ───────────────────────────

@test "generated LICENSE.md contains MIT license text" {
  run "$LICENSE_GEN" --component "savia-mit-test" --year 2026 --org "Test Org" --output-dir "$TEST_TMPDIR"
  [ "$status" -eq 0 ]
  [[ -f "${TEST_TMPDIR}/LICENSE.md" ]]
  grep -qi "MIT License\|Permission is hereby granted" "${TEST_TMPDIR}/LICENSE.md"
}

# ── Test 4: commercial-terms-check.sh exists and is executable ───────────────

@test "commercial-terms-check.sh exists and is executable" {
  [[ -f "$TERMS_CHECK" ]]
  [[ -x "$TERMS_CHECK" ]]
}

# ── Test 5: commercial-terms-check.sh produces JSON output ───────────────────

@test "commercial-terms-check.sh produces JSON with compliant field" {
  run "$TERMS_CHECK"
  # Exit 0 (compliant) or 1 (issues found) — both valid for this test
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # Output must contain compliant field
  echo "$output" | grep -q '"compliant"'
}

# ── Test 6: enterprise-licensing-policy.md exists ────────────────────────────

@test "enterprise-licensing-policy.md exists" {
  [[ -f "$LICENSING_POLICY" ]]
}

# ── Test 7: licensing policy references MIT ───────────────────────────────────

@test "enterprise-licensing-policy.md references MIT license" {
  [[ -f "$LICENSING_POLICY" ]]
  grep -qi "MIT" "$LICENSING_POLICY"
}
