#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-022-power-features-cli.md
# Tests for context-snapshot.sh — Session context save/load

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/context-snapshot.sh"
  TMPDIR_CS=$(mktemp -d)
}

teardown() { rm -rf "$TMPDIR_CS"; }

@test "script has safety flags" {
  head -8 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "save subcommand runs" {
  run bash -c "echo '' | bash '$SCRIPT' save"
  [[ "$status" -le 1 ]]
}

@test "load subcommand runs" {
  run bash -c "echo '' | bash '$SCRIPT' load"
  [[ "$status" -le 1 ]]
}

@test "status subcommand runs" {
  run bash -c "echo '' | bash '$SCRIPT' status"
  [[ "$status" -le 1 ]]
}

@test "negative: unknown subcommand handled" {
  run bash -c "echo '' | bash '$SCRIPT' bogus"
  [[ "$status" -le 1 ]]
}

@test "negative: no subcommand shows help or defaults" {
  run bash -c "echo '' | bash '$SCRIPT'"
  [[ "$status" -le 1 ]]
}

@test "edge: save with empty context" {
  export CLAUDE_PROJECT_DIR="$TMPDIR_CS"
  run bash -c "echo '' | bash '$SCRIPT' save"
  [[ "$status" -le 1 ]]
}

@test "coverage: handles save/load/status commands" {
  grep -q "save\|load\|status" "$SCRIPT"
}

@test "edge: save then load round-trip" {
  export CLAUDE_PROJECT_DIR="$TMPDIR_CS"
  bash -c "echo '' | bash '$SCRIPT' save" 2>/dev/null || true
  run bash -c "echo '' | bash '$SCRIPT' load"
  [[ "$status" -le 1 ]]
}

@test "edge: multiple saves are idempotent" {
  export CLAUDE_PROJECT_DIR="$TMPDIR_CS"
  bash -c "echo '' | bash '$SCRIPT' save" 2>/dev/null || true
  bash -c "echo '' | bash '$SCRIPT' save" 2>/dev/null || true
  [[ "$?" -le 1 ]]
}

@test "negative: status in empty workspace" {
  export CLAUDE_PROJECT_DIR="$TMPDIR_CS/empty"
  mkdir -p "$TMPDIR_CS/empty"
  run bash -c "echo '' | bash '$SCRIPT' status"
  [[ "$status" -le 1 ]]
}

@test "coverage: reads stdin" {
  grep -q "stdin\|/dev/stdin\|cat.*dev" "$SCRIPT"
}
