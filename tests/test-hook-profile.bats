#!/usr/bin/env bats
# Tests for hook-profile.sh — Hook profile manager

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/hook-profile.sh"
  TMPDIR_HP=$(mktemp -d)
  export HOME="$TMPDIR_HP"
  unset SAVIA_HOOK_PROFILE
}

teardown() {
  rm -rf "$TMPDIR_HP"
}

@test "get returns standard as default" {
  run bash "$SCRIPT" get
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"standard"* ]]
  [[ "$output" == *"default"* ]]
}

@test "set minimal creates profile file" {
  run bash "$SCRIPT" set minimal
  [[ "$status" -eq 0 ]]
  [[ -f "$TMPDIR_HP/.savia/hook-profile" ]]
  [[ "$(cat "$TMPDIR_HP/.savia/hook-profile")" == "minimal" ]]
}

@test "set strict persists and reports" {
  run bash "$SCRIPT" set strict
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"strict"* ]]
  run bash "$SCRIPT" get
  [[ "$output" == *"strict"* ]]
}

@test "set invalid profile fails" {
  run bash "$SCRIPT" set bogus
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"unknown profile"* ]]
}

@test "set without name fails" {
  run bash "$SCRIPT" set
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"profile name required"* ]]
}

@test "env var overrides file" {
  bash "$SCRIPT" set minimal
  export SAVIA_HOOK_PROFILE=ci
  run bash "$SCRIPT" get
  [[ "$output" == *"ci"* ]]
  [[ "$output" == *"env var"* ]]
}

@test "list shows all 4 profiles" {
  run bash "$SCRIPT" list
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"minimal"* ]]
  [[ "$output" == *"standard"* ]]
  [[ "$output" == *"strict"* ]]
  [[ "$output" == *"ci"* ]]
}

@test "help flag shows usage" {
  run bash "$SCRIPT" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]]
}

@test "unknown command fails with usage" {
  run bash "$SCRIPT" destroy
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Unknown command"* ]]
}

@test "set all 4 valid profiles succeeds" {
  for p in minimal standard strict ci; do
    run bash "$SCRIPT" set "$p"
    [[ "$status" -eq 0 ]]
  done
}
