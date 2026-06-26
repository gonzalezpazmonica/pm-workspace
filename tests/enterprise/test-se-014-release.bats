#!/usr/bin/env bats
# test-se-014-release.bats — SE-014 Release Orchestration
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-014-release-orchestration.md

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  RELEASE_CREATE="${REPO_ROOT}/scripts/enterprise/release-create.sh"
  GATE_CHECK="${REPO_ROOT}/scripts/enterprise/release-gate-check.sh"
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR REPO_ROOT

  # Override tenants dir to tmpdir
  export SAVIA_TENANTS_ROOT="${TEST_TMPDIR}/tenants"
  mkdir -p "${SAVIA_TENANTS_ROOT}"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── release-create.sh ────────────────────────────────────────────────────────

@test "SE-014: release-create.sh exists and is executable" {
  [[ -f "$RELEASE_CREATE" ]]
  [[ -x "$RELEASE_CREATE" ]]
}

@test "SE-014: release-create.sh --help exits 0" {
  run bash "$RELEASE_CREATE" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"version"* ]]
}

@test "SE-014: release-create.sh fails without required args" {
  run bash "$RELEASE_CREATE"
  [ "$status" -eq 2 ]
}

@test "SE-014: release-create.sh creates release.yaml with basic profile" {
  local tenant="test-tenant-$$"
  local version="1.0.0"
  local tenants_dir="${TEST_TMPDIR}/tenants"

  # Create tenant dir as script expects
  mkdir -p "${tenants_dir}/${tenant}"

  # Run with REPO_ROOT pointing to TEST_TMPDIR so tenants/{slug}/ resolves
  REPO_ROOT_OVERRIDE="${TEST_TMPDIR}"
  run bash -c "
    set -uo pipefail
    REPO_ROOT='${TEST_TMPDIR}' bash '${RELEASE_CREATE}' \
      --version '${version}' \
      --tenant '${tenant}' \
      --compliance-profile basic
  "
  [ "$status" -eq 0 ]

  local release_file="${TEST_TMPDIR}/tenants/${tenant}/releases/${version}/release.yaml"
  [[ -f "$release_file" ]]
  grep -q "version: \"${version}\"" "$release_file"
  grep -q "status: draft" "$release_file"
  grep -q "compliance_profile: \"basic\"" "$release_file"
}

@test "SE-014: release-create.sh creates checklist for dora profile" {
  local tenant="test-dora-$$"
  local version="2.0.0"

  run bash -c "
    REPO_ROOT='${TEST_TMPDIR}' bash '${RELEASE_CREATE}' \
      --version '${version}' \
      --tenant '${tenant}' \
      --compliance-profile dora
  "
  [ "$status" -eq 0 ]

  local release_file="${TEST_TMPDIR}/tenants/${tenant}/releases/${version}/release.yaml"
  [[ -f "$release_file" ]]
  grep -q "change_window_approved" "$release_file"
  grep -q "rollback_playbook_tested" "$release_file"
}

@test "SE-014: release-create.sh rejects invalid compliance profile" {
  run bash "$RELEASE_CREATE" --version "1.0.0" --tenant "test" --compliance-profile "invalid"
  [ "$status" -eq 2 ]
  [[ "$output" == *"basic|eu-ai-act|dora"* ]]
}

@test "SE-014: release-create.sh fails on duplicate release" {
  local tenant="test-dup-$$"
  local version="3.0.0"

  # First creation
  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${RELEASE_CREATE}' \
    --version '${version}' --tenant '${tenant}' --compliance-profile basic" >/dev/null 2>&1

  # Second should fail
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${RELEASE_CREATE}' \
    --version '${version}' --tenant '${tenant}' --compliance-profile basic"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

# ── release-gate-check.sh ────────────────────────────────────────────────────

@test "SE-014: release-gate-check.sh exists and is executable" {
  [[ -f "$GATE_CHECK" ]]
  [[ -x "$GATE_CHECK" ]]
}

@test "SE-014: release-gate-check.sh fails without required args" {
  run bash "$GATE_CHECK"
  [ "$status" -eq 2 ]
}

@test "SE-014: release-gate-check.sh returns not-ready when gates pending" {
  local tenant="test-gates-$$"
  local version="4.0.0"

  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${RELEASE_CREATE}' \
    --version '${version}' --tenant '${tenant}' --compliance-profile basic" >/dev/null 2>&1

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${GATE_CHECK}' \
    --version '${version}' --tenant '${tenant}'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ready_to_deploy\":false"* ]]
}

@test "SE-014: release-gate-check.sh returns valid JSON" {
  local tenant="test-json-$$"
  local version="5.0.0"

  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${RELEASE_CREATE}' \
    --version '${version}' --tenant '${tenant}' --compliance-profile basic" >/dev/null 2>&1

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${GATE_CHECK}' \
    --version '${version}' --tenant '${tenant}'"

  # Output should contain JSON keys
  [[ "$output" == *"\"version\""* ]]
  [[ "$output" == *"\"gates\""* ]]
  [[ "$output" == *"\"ready_to_deploy\""* ]]
}

@test "SE-014: release-gate-check.sh exits 3 for non-existent release" {
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${GATE_CHECK}' \
    --version 'nonexistent' --tenant 'nobody'"
  [ "$status" -eq 3 ]
}
