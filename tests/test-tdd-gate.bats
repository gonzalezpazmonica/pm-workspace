#!/usr/bin/env bats
# BATS tests for tdd-gate.sh
# SCRIPT=.claude/hooks/tdd-gate.sh
# SPEC: SPEC-081 — Hook test coverage

SCRIPT=".claude/hooks/tdd-gate.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export SAVIA_HOOK_PROFILE="standard"
  export TEST_TMPDIR="$TMPDIR/tdd-gate-$$"
  mkdir -p "$TEST_TMPDIR"
  # Init a git repo so the hook can find the project root
  cd "$TEST_TMPDIR"
  git init -q .
  export CLAUDE_PROJECT_DIR="$TEST_TMPDIR"
}

teardown() {
  unset SAVIA_HOOK_PROFILE CLAUDE_PROJECT_DIR
  rm -rf "$TEST_TMPDIR"
}

@test "script exists and is executable" {
  cd "$BATS_TEST_DIRNAME/.."
  [[ -x "$SCRIPT" ]]
}

@test "script has set -uo pipefail" {
  cd "$BATS_TEST_DIRNAME/.."
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "allow: non-Edit/Write tool passes through" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | bash "$SCRIPT"
}

@test "allow: Edit on markdown file passes through" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_name":"Edit","tool_input":{"file_path":"docs/README.md"}}' | bash "$SCRIPT"
}

@test "allow: Edit on test file passes through" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_name":"Edit","tool_input":{"file_path":"src/UserServiceTest.cs"}}' | bash "$SCRIPT"
}

@test "allow: Edit on spec file passes through" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_name":"Edit","tool_input":{"file_path":"src/user.spec.ts"}}' | bash "$SCRIPT"
}

@test "allow: Edit on migration file passes through" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_name":"Edit","tool_input":{"file_path":"src/Migration001.cs"}}' | bash "$SCRIPT"
}

@test "allow: Edit on config file passes through" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_name":"Edit","tool_input":{"file_path":"src/appsettings.json"}}' | bash "$SCRIPT"
}

@test "allow: Edit on file in nested tests/ directory passes through" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_name":"Edit","tool_input":{"file_path":"src/tests/helper.py"}}' | bash "$SCRIPT"
}

@test "allow: Edit on Dockerfile passes through" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_name":"Edit","tool_input":{"file_path":"Dockerfile"}}' | bash "$SCRIPT"
}

@test "allow: production .cs file WITH test present" {
  # Create the production file and its test in TEST_TMPDIR
  mkdir -p "$TEST_TMPDIR/src"
  touch "$TEST_TMPDIR/src/UserService.cs"
  touch "$TEST_TMPDIR/src/UserServiceTest.cs"
  cd "$TEST_TMPDIR"
  local FULL_SCRIPT
  FULL_SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/$SCRIPT"
  echo '{"tool_name":"Edit","tool_input":{"file_path":"src/UserService.cs"}}' | bash "$FULL_SCRIPT"
}

@test "block: production .cs file WITHOUT test" {
  mkdir -p "$TEST_TMPDIR/src"
  touch "$TEST_TMPDIR/src/OrderService.cs"
  cd "$TEST_TMPDIR"
  local FULL_SCRIPT
  FULL_SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/$SCRIPT"
  run bash -c 'echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"src/OrderService.cs\"}}" | bash '"$FULL_SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"TDD GATE"* ]]
}

@test "block: production .py file WITHOUT test" {
  mkdir -p "$TEST_TMPDIR/src"
  touch "$TEST_TMPDIR/src/handler.py"
  cd "$TEST_TMPDIR"
  local FULL_SCRIPT
  FULL_SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/$SCRIPT"
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"src/handler.py\"}}" | bash '"$FULL_SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"TDD GATE"* ]]
}

@test "allow: production .py file WITH test_handler.py present" {
  mkdir -p "$TEST_TMPDIR/src"
  touch "$TEST_TMPDIR/src/handler.py"
  touch "$TEST_TMPDIR/src/test_handler.py"
  cd "$TEST_TMPDIR"
  local FULL_SCRIPT
  FULL_SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/$SCRIPT"
  echo '{"tool_name":"Edit","tool_input":{"file_path":"src/handler.py"}}' | bash "$FULL_SCRIPT"
}

@test "edge: empty input exits 0" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{}' | bash "$SCRIPT"
}

@test "edge: missing file_path exits 0" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_name":"Edit","tool_input":{}}' | bash "$SCRIPT"
}

@test "edge: malformed JSON handled gracefully" {
  cd "$BATS_TEST_DIRNAME/.."
  echo 'not valid json' | bash "$SCRIPT"
}

@test "skip: minimal profile skips the gate" {
  export SAVIA_HOOK_PROFILE="minimal"
  cd "$BATS_TEST_DIRNAME/.."
  # This would block in standard, but minimal skips standard-tier hooks
  mkdir -p "$TEST_TMPDIR/src"
  touch "$TEST_TMPDIR/src/NoTestService.cs"
  echo '{"tool_name":"Edit","tool_input":{"file_path":"'"$TEST_TMPDIR"'/src/NoTestService.cs"}}' | bash "$SCRIPT"
}

@test "coverage: uses jq for JSON parsing" {
  cd "$BATS_TEST_DIRNAME/.."
  grep -q "jq" "$SCRIPT"
}

@test "coverage: has find for test discovery" {
  cd "$BATS_TEST_DIRNAME/.."
  grep -q "find" "$SCRIPT"
}
