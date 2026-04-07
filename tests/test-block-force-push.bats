#!/usr/bin/env bats
# BATS tests for block-force-push.sh — SPEC-032 audit coverage

SCRIPT=".claude/hooks/block-force-push.sh"

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script has safety flags" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "passes clean git push" {
  echo '{"tool_input":{"command":"git push origin feat/my-branch"}}' | bash "$SCRIPT"
}

@test "passes empty input" {
  echo '{}' | bash "$SCRIPT"
}

@test "blocks git push --force" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"git push --force origin main\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "blocks git push -f" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"git push -f origin main\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "blocks push to main" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"git push origin main\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "blocks push to master" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"git push origin master\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "blocks git commit --amend" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"git commit --amend -m fix\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "blocks git reset --hard" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"git reset --hard HEAD~1\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "passes normal git commit" {
  echo '{"tool_input":{"command":"git commit -m \"feat: add feature\""}}' | bash "$SCRIPT"
}

@test "passes git push to feature branch" {
  echo '{"tool_input":{"command":"git push origin feat/spec-079"}}' | bash "$SCRIPT"
}
