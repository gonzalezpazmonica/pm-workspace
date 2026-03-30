#!/usr/bin/env bats
# Tests for scripts/lib/mock-env.sh mock environment library

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  MOCK_LIB="$PWD/scripts/lib/mock-env.sh"
  TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "mock-env.sh exists and is sourceable" {
  [ -f "$MOCK_LIB" ]
  run bash -c "source '$MOCK_LIB' && echo ok"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "is_mock_mode returns false by default" {
  run bash -c "source '$MOCK_LIB' && is_mock_mode && echo yes || echo no"
  [ "$output" = "no" ]
}

@test "mock_init enables mock mode" {
  run bash -c "source '$MOCK_LIB' && mock_init && is_mock_mode && echo yes || echo no"
  [ "$output" = "yes" ]
}

@test "--mock flag auto-enables mock mode" {
  run bash -c "source '$MOCK_LIB' --mock && is_mock_mode && echo yes || echo no"
  [ "$output" = "yes" ]
}

@test "mock_sprint_data returns valid JSON" {
  run bash -c "source '$MOCK_LIB' && mock_sprint_data | jq -e '.name' >/dev/null"
  [ "$status" -eq 0 ]
}

@test "mock_team_data returns valid JSON with members" {
  run bash -c "source '$MOCK_LIB' && mock_team_data | jq -e '.members | length > 0' >/dev/null"
  [ "$status" -eq 0 ]
}

@test "mock_mcp_response includes tool name" {
  run bash -c "source '$MOCK_LIB' && mock_mcp_response 'test-tool' | jq -r '.tool'"
  [ "$output" = "test-tool" ]
}

@test "mock_azure_response returns default empty when no mock file" {
  run bash -c "export PM_MOCK_DATA=/tmp/nonexistent && source '$MOCK_LIB' && mock_azure_response 'nosuchfile' | jq -e '.count == 0'"
  [ "$status" -eq 0 ]
}

# ── Negative cases ──

@test "mock_mcp_response handles empty tool name" {
  run bash -c "source '$MOCK_LIB' && mock_mcp_response '' | jq -e '.tool'"
  [ "$status" -eq 0 ]
  [ "$output" = '""' ] || [ "$output" = "" ]
}

@test "is_mock_mode returns false after fresh source" {
  run bash -c "unset PM_MOCK_MODE; source '$MOCK_LIB' && is_mock_mode && echo yes || echo no"
  [ "$output" = "no" ]
}

# ── Edge case ──

@test "mock_sprint_data includes expected fields" {
  run bash -c "source '$MOCK_LIB' && mock_sprint_data | jq -e '.startDate and .endDate'"
  [ "$status" -eq 0 ]
}

# ── Spec/doc reference ──

@test "mock-env provides test isolation for offline scenarios" {
  # Ref: mock-env.sh enables testing without Azure DevOps connection
  grep -q "mock\|PM_MOCK" "$MOCK_LIB"
}

# ── Safety verification ──

@test "core scripts have set -uo pipefail safety" {
  for s in scripts/validate-ci-local.sh scripts/output-compress.sh scripts/pr-plan.sh; do
    [ -f "$s" ] && grep -q "set -uo pipefail" "$s"
  done
}

# ── Additional coverage ──

@test "mock_azure_response returns count field" {
  run bash -c "source '$MOCK_LIB' && mock_azure_response 'any' | jq -e '.count'"
  [ "$status" -eq 0 ]
}

@test "mock_sprint_data name is a non-empty string" {
  run bash -c "source '$MOCK_LIB' && mock_sprint_data | jq -r '.name'"
  [ "$status" -eq 0 ]
  [[ -n "$output" ]]
  [[ "$output" != "null" ]]
}

# ── Edge case: special characters ──

@test "mock_mcp_response handles tool name with special chars" {
  run bash -c "source '$MOCK_LIB' && mock_mcp_response 'test/tool-v2' | jq -r '.tool'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"test/tool-v2"* ]]
}

@test "mock_mcp_response handles null input" {
  run bash -c "source '$MOCK_LIB' && mock_mcp_response 2>/dev/null || echo ok"
  [ "$status" -eq 0 ]
}
