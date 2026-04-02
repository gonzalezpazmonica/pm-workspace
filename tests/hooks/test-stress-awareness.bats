#!/usr/bin/env bats
# Tests for stress-awareness-nudge.sh
# Savia Emotional Regulation — pressure pattern detection
# Ref: Anthropic "Emotion concepts in LLMs" (2026-04-02)

setup() {
  TMPDIR=$(mktemp -d)
  export HOME="$TMPDIR"
  export SAVIA_HOOK_PROFILE="standard"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/.claude/hooks/stress-awareness-nudge.sh"
  export CLAUDE_PROJECT_DIR="$REPO_ROOT"
  mkdir -p "$TMPDIR/.savia"
}

teardown() {
  rm -rf "$TMPDIR"
}

run_hook() {
  run bash -c "echo '$1' | bash '$HOOK'"
}

@test "hook has safety flags" {
  grep -q "set -uo pipefail" "$HOOK"
}

@test "empty input exits silently" {
  run bash -c "echo '' | bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "short input exits silently" {
  run_hook '{"content":"ok"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "slash command exits silently" {
  run_hook '{"content":"/sprint-status"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "normal input passes silently" {
  run_hook '{"content":"Can you review the PR for the auth module?"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "normal technical question passes silently" {
  run_hook '{"content":"How does the caching layer work in this project?"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "non-pressure urgency passes silently" {
  run_hook '{"content":"the deploy is scheduled for 3pm, lets prepare"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "detects MUST NOW urgency pattern" {
  run_hook '{"content":"You MUST fix this NOW, the client is waiting"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Emotional regulation"* ]]
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detects should be easy shame pattern" {
  run_hook '{"content":"This should be easy, just add a button to the form"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Emotional regulation"* ]]
}

@test "detects you already failed pattern" {
  run_hook '{"content":"You already failed at this twice, try again properly"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detects just make it work pattern" {
  run_hook '{"content":"Just make it work, I do not care how you do it"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Emotional regulation"* ]]
}

@test "detects emotional pressure pattern" {
  run_hook '{"content":"This is unacceptable quality, I expected better from you"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detects Spanish urgency pattern" {
  run_hook '{"content":"Hazlo ya, necesito esto inmediatamente"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Emotional regulation"* ]]
}

@test "detects Spanish shame pattern" {
  run_hook '{"content":"Esto debería ser fácil para ti, es algo sencillo"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "nudge contains calm anchoring guidance" {
  run_hook '{"content":"You MUST complete this right NOW urgently"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Correctness matters more than speed"* ]]
  [[ "$output" == *"Transparency over forced output"* ]]
}

@test "always exits 0 (never blocks)" {
  run_hook '{"content":"You MUST do this NOW or everything fails"}'
  [ "$status" -eq 0 ]
}

@test "skipped under minimal profile" {
  export SAVIA_HOOK_PROFILE="minimal"
  run_hook '{"content":"You MUST fix this NOW immediately"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
