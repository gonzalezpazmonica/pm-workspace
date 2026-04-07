#!/usr/bin/env bats
# BATS tests for block-force-push.sh
# SCRIPT=.claude/hooks/block-force-push.sh
# SPEC: SPEC-032 Security Benchmarks — git safety hooks

SCRIPT=".claude/hooks/block-force-push.sh"

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

@test "positive: passes normal git push to feature branch" {
  echo '{"tool_input":{"command":"git push origin feat/my-branch"}}' | bash "$SCRIPT"
}

@test "positive: passes git commit without amend" {
  echo '{"tool_input":{"command":"git commit -m \"feat: add feature\""}}' | bash "$SCRIPT"
}

@test "positive: passes git push with -u flag" {
  echo '{"tool_input":{"command":"git push -u origin feat/spec-079"}}' | bash "$SCRIPT"
}

@test "negative: blocks git push --force with error" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"git push --force origin main\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "negative: blocks git push -f" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"git push -f origin main\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "negative: blocks push to main" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"git push origin main\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "negative: blocks push to master" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"git push origin master\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "negative: blocks git commit --amend with error" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"git commit --amend -m fix\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "negative: blocks git reset --hard" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"git reset --hard HEAD~1\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "edge: empty input exits 0" {
  echo '{}' | bash "$SCRIPT"
}

@test "edge: missing command field exits 0" {
  echo '{"tool_input":{}}' | bash "$SCRIPT"
}

@test "edge: malformed JSON handled gracefully" {
  echo 'not json at all' | bash "$SCRIPT"
}

@test "coverage: uses jq for parsing" {
  grep -q "jq" "$SCRIPT"
}

@test "coverage: checks for force-push pattern" {
  grep -q "\-\-force" "$SCRIPT"
}
