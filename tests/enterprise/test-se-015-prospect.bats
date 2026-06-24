#!/usr/bin/env bats
# test-se-015-prospect.bats — SE-015 Project Prospect (Pipeline-as-Code)
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-015-project-prospect.md

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  PROSPECT_CREATE="${REPO_ROOT}/scripts/enterprise/prospect-create.sh"
  PIPELINE="${REPO_ROOT}/scripts/enterprise/prospect-pipeline.sh"
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR REPO_ROOT
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── prospect-create.sh ───────────────────────────────────────────────────────

@test "SE-015: prospect-create.sh exists and is executable" {
  [[ -f "$PROSPECT_CREATE" ]]
  [[ -x "$PROSPECT_CREATE" ]]
}

@test "SE-015: prospect-create.sh --help exits 0" {
  run bash "$PROSPECT_CREATE" --help
  [ "$status" -eq 0 ]
}

@test "SE-015: prospect-create.sh fails without required args" {
  run bash "$PROSPECT_CREATE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"required"* ]]
}

@test "SE-015: prospect-create.sh creates prospect.yaml with correct fields" {
  local tenant="acme-$$"
  local slug="bank-modernization"
  local client="MegaBank EU"
  local value="1200000"

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${PROSPECT_CREATE}' \
    --slug '${slug}' \
    --client '${client}' \
    --value '${value}' \
    --tenant '${tenant}' \
    --stage discovery"
  [ "$status" -eq 0 ]

  local prospect_file="${TEST_TMPDIR}/tenants/${tenant}/prospects/${slug}/prospect.yaml"
  [[ -f "$prospect_file" ]]
  grep -q "client: \"${client}\"" "$prospect_file"
  grep -q "value_eur: ${value}" "$prospect_file"
  grep -q "stage: \"discovery\"" "$prospect_file"
  grep -q "bant:" "$prospect_file"
}

@test "SE-015: prospect-create.sh stores all valid stages" {
  for stage in qualified proposal won lost; do
    local slug="test-${stage}-$$"
    run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${PROSPECT_CREATE}' \
      --slug '${slug}' --client 'Client' --value 5000 --tenant 'tenant-$$' --stage '${stage}'"
    [ "$status" -eq 0 ]
  done
}

@test "SE-015: prospect-create.sh rejects invalid stage" {
  run bash "$PROSPECT_CREATE" \
    --slug "test" --client "Cl" --value 1000 --tenant "t" --stage "invalid"
  [ "$status" -eq 2 ]
}

@test "SE-015: prospect-create.sh rejects non-numeric value" {
  run bash "$PROSPECT_CREATE" \
    --slug "test" --client "Cl" --value "abc" --tenant "t" --stage "discovery"
  [ "$status" -eq 2 ]
}

@test "SE-015: prospect-create.sh fails on duplicate slug" {
  local slug="dup-prospect-$$"
  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${PROSPECT_CREATE}' \
    --slug '${slug}' --client 'Client' --value 5000 --tenant 'acme'" >/dev/null 2>&1
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${PROSPECT_CREATE}' \
    --slug '${slug}' --client 'Client' --value 5000 --tenant 'acme'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

# ── prospect-pipeline.sh ─────────────────────────────────────────────────────

@test "SE-015: prospect-pipeline.sh exists and is executable" {
  [[ -f "$PIPELINE" ]]
  [[ -x "$PIPELINE" ]]
}

@test "SE-015: prospect-pipeline.sh --json returns JSON for empty tenant" {
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${PIPELINE}' \
    --tenant 'empty-tenant-$$' --json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"prospects\""* ]]
  [[ "$output" == *"\"count\""* ]]
}

@test "SE-015: prospect-pipeline.sh lists created prospects" {
  local tenant="pipeline-tenant-$$"
  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${PROSPECT_CREATE}' \
    --slug opp1 --client 'Client A' --value 50000 --tenant '${tenant}' --stage discovery" >/dev/null 2>&1
  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${PROSPECT_CREATE}' \
    --slug opp2 --client 'Client B' --value 80000 --tenant '${tenant}' --stage proposal" >/dev/null 2>&1

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${PIPELINE}' \
    --tenant '${tenant}' --json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"count\":2"* ]]
  [[ "$output" == *"opp1"* ]]
  [[ "$output" == *"opp2"* ]]
}

@test "SE-015: prospect-pipeline.sh --stage filter works" {
  local tenant="filter-tenant-$$"
  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${PROSPECT_CREATE}' \
    --slug opp-discovery --client 'A' --value 10000 --tenant '${tenant}' --stage discovery" >/dev/null 2>&1
  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${PROSPECT_CREATE}' \
    --slug opp-won --client 'B' --value 20000 --tenant '${tenant}' --stage won" >/dev/null 2>&1

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${PIPELINE}' \
    --tenant '${tenant}' --stage discovery --json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"count\":1"* ]]
  [[ "$output" == *"opp-discovery"* ]]
  [[ "$output" != *"opp-won"* ]]
}
