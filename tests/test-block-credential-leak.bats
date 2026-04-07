#!/usr/bin/env bats
# BATS tests for block-credential-leak.sh
# SCRIPT=.claude/hooks/block-credential-leak.sh
# SPEC: SPEC-032 Security Benchmarks — hook coverage for corporate audit

SCRIPT=".claude/hooks/block-credential-leak.sh"

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

@test "positive: passes clean ls command" {
  echo '{"tool_input":{"command":"ls -la /tmp"}}' | bash "$SCRIPT"
}

@test "positive: passes git status" {
  echo '{"tool_input":{"command":"git status"}}' | bash "$SCRIPT"
}

@test "positive: passes dotnet build" {
  echo '{"tool_input":{"command":"dotnet build --configuration Release"}}' | bash "$SCRIPT"
}

@test "negative: blocks password= with error message" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"curl -u user:password=SuperSecret123 http://x\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* || "$output" == *"secret"* ]]
}

@test "negative: blocks api_key= with error output" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"export api_key=sk-1234567890abcdef1234\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "negative: blocks token= pattern" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"curl -H token=ghp_ABCDEFghijklmnopqrstuvwxyz123456\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "negative: blocks connection_string= with password" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"export connection_string=Server=myserver;Password=realpass123\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "edge: empty input exits 0" {
  echo '{}' | bash "$SCRIPT"
}

@test "edge: missing command field exits 0" {
  echo '{"tool_input":{}}' | bash "$SCRIPT"
}

@test "edge: malformed JSON handled gracefully" {
  echo 'not valid json' | bash "$SCRIPT"
}

@test "edge: short value not blocked (boundary <8 chars)" {
  echo '{"tool_input":{"command":"export password=abc"}}' | bash "$SCRIPT"
}

@test "coverage: uses jq for JSON parsing" {
  grep -q "jq" "$SCRIPT"
}

@test "coverage: SECRETS_PATTERN variable defined" {
  grep -q "SECRETS_PATTERN" "$SCRIPT"
}
