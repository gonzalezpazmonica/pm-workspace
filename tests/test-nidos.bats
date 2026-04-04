#!/usr/bin/env bats
# Ref: .claude/rules/domain/nidos-protocol.md
# Tests for nidos.sh — Savia Nidos worktree manager

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/nidos.sh"
  TMPDIR_NI=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_NI"
}

@test "help shows usage" {
  run bash "$SCRIPT" help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"nidos"* ]]
}

@test "list with no nidos shows empty message" {
  export HOME="$TMPDIR_NI"
  run bash "$SCRIPT" list
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"No active nidos"* ]] || [[ "$output" == *"NAME"* ]]
}

@test "status outside nido reports not in nido" {
  run bash "$SCRIPT" status
  [[ "$status" -eq 0 ]]
}

@test "create without name fails" {
  run bash "$SCRIPT" create
  [[ "$status" -ne 0 ]]
}

@test "remove nonexistent nido fails" {
  export HOME="$TMPDIR_NI"
  run bash "$SCRIPT" remove nonexistent
  [[ "$status" -ne 0 ]]
}

@test "unknown command shows error" {
  run bash "$SCRIPT" destroy
  [[ "$status" -ne 0 ]] || [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "nidos-lib.sh exists and is sourceable" {
  [[ -f "$REPO_ROOT/scripts/nidos-lib.sh" ]]
  run bash -n "$REPO_ROOT/scripts/nidos-lib.sh"
  [[ "$status" -eq 0 ]]
}

@test "script has set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "edge: create with special chars in name fails" {
  run bash "$SCRIPT" create "../escape"
  [[ "$status" -ne 0 ]]
}

@test "edge: enter nonexistent nido fails" {
  export HOME="$TMPDIR_NI"
  run bash "$SCRIPT" enter nonexistent
  [[ "$status" -ne 0 ]]
}

@test "do_create function exists" {
  grep -q "do_create()" "$SCRIPT"
}

@test "do_remove function exists" {
  grep -q "do_remove()" "$SCRIPT"
}

@test "do_status function exists" {
  grep -q "do_status()" "$SCRIPT"
}
