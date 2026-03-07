#!/usr/bin/env bats
# Tests for scripts/lib/mock-env.sh mock environment library

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  MOCK_LIB="$PWD/scripts/lib/mock-env.sh"
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
