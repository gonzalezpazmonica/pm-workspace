#!/usr/bin/env bats
# BATS tests for block-project-whitelist.sh
# SCRIPT=.opencode/hooks/block-project-whitelist.sh
# SPEC: SPEC-081 — Hook test coverage

SCRIPT=".opencode/hooks/block-project-whitelist.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export SAVIA_HOOK_PROFILE="standard"
  export CLAUDE_PROJECT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

teardown() {
  unset SAVIA_HOOK_PROFILE CLAUDE_PROJECT_DIR CLAUDE_TOOL_INPUT
}

@test "script exists and is executable" {
  cd "$BATS_TEST_DIRNAME/.."
  [[ -x "$SCRIPT" ]]
}

@test "script has set -uo pipefail" {
  cd "$BATS_TEST_DIRNAME/.."
  head -5 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "allow: non-gitignore file exits 0" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT="file_path: src/main.cs"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "allow: editing .gitignore without whitelist exits 0" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT="editing .gitignore with node_modules/"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "allow: empty input exits 0" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT=""
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "block: gitignore with !projects/ whitelist" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT="editing .gitignore adding !projects/secret-client/"
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "block: gitignore with !projects/alpha whitelist" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT=".gitignore content: !projects/alpha/"
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "block: mentions privacy requirement in message" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT=".gitignore !projects/new-project/"
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"privacidad"* || "$output" == *"confirmación humana"* ]]
}

@test "allow: gitignore with projects/ (no exclamation)" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT=".gitignore projects/"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "skip: minimal profile skips the gate" {
  export SAVIA_HOOK_PROFILE="minimal"
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT=".gitignore !projects/secret/"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "allow: regular gitignore patterns pass" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT=".gitignore output/ node_modules/ *.log"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "coverage: checks for !projects/ pattern" {
  cd "$BATS_TEST_DIRNAME/.."
  grep -qE '!projects/' "$SCRIPT"
}

@test "coverage: references CLAUDE_TOOL_INPUT" {
  cd "$BATS_TEST_DIRNAME/.."
  grep -q "CLAUDE_TOOL_INPUT" "$SCRIPT"
}
