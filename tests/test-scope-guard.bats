#!/usr/bin/env bats
# BATS tests for scope-guard.sh
# SCRIPT=.opencode/hooks/scope-guard.sh
# SPEC: SPEC-032 Security Benchmarks — scope isolation

SCRIPT=".opencode/hooks/scope-guard.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export SAVIA_HOOK_PROFILE="standard"
  export CLAUDE_PROJECT_DIR="$(pwd)"
}

teardown() {
  unset SAVIA_HOOK_PROFILE
}

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script has set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "positive: passes with empty input" {
  echo '{}' | bash "$SCRIPT"
}

@test "positive: passes when no spec scope is active" {
  echo '{"tool_input":{"file_path":"/tmp/test.md"}}' | bash "$SCRIPT"
}

@test "positive: passes with Edit tool input" {
  echo '{"tool_input":{"file_path":"src/main.rs","old_string":"a","new_string":"b"}}' | bash "$SCRIPT"
}

@test "positive: passes normal file write" {
  echo '{"tool_input":{"file_path":"output/test.md","content":"hello"}}' | bash "$SCRIPT"
}

@test "negative: exits 0 always — warning only not blocking" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"random/file.txt\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "edge: handles missing file_path gracefully" {
  echo '{"tool_input":{"command":"ls"}}' | bash "$SCRIPT"
}

@test "edge: handles malformed JSON" {
  echo 'not json' | bash "$SCRIPT"
}

@test "edge: handles empty string file_path" {
  echo '{"tool_input":{"file_path":""}}' | bash "$SCRIPT"
}

@test "coverage: reads tool_input from stdin" {
  grep -q "tool_input\|INPUT\|stdin\|cat" "$SCRIPT"
}

@test "coverage: profile gate check present" {
  grep -q "profile_gate\|SAVIA_HOOK_PROFILE" "$SCRIPT"
}
