#!/usr/bin/env bats
# Tests for company-repo.sh — Company Savia repo lifecycle

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/company-repo.sh"

setup() {
  export TMPDIR_TEST=$(mktemp -d)
  export HOME="$TMPDIR_TEST/home"
  mkdir -p "$HOME/.pm-workspace"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "company-repo: script is valid bash" {
  bash -n "$SCRIPT"
}

@test "company-repo: uses set -euo pipefail" {
  grep -q "set -euo pipefail" "$SCRIPT"
}

@test "company-repo: help shows all 4 commands" {
  run bash "$SCRIPT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"create"* ]]
  [[ "$output" == *"connect"* ]]
  [[ "$output" == *"status"* ]]
  [[ "$output" == *"sync"* ]]
}

@test "company-repo: no args shows help" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"company-repo.sh"* ]]
}

@test "company-repo: create without args fails" {
  run bash "$SCRIPT" create
  [ "$status" -ne 0 ]
}

@test "company-repo: savia-compat.sh dependency exists" {
  local compat="$BATS_TEST_DIRNAME/../../scripts/savia-compat.sh"
  [ -f "$compat" ]
}

@test "company-repo: company-repo-ops.sh dependency exists" {
  local ops="$BATS_TEST_DIRNAME/../../scripts/company-repo-ops.sh"
  [ -f "$ops" ]
}

@test "company-repo: company-repo-templates.sh dependency exists" {
  local tmpl="$BATS_TEST_DIRNAME/../../scripts/company-repo-templates.sh"
  [ -f "$tmpl" ]
}

@test "company-repo: status without config handles gracefully" {
  export HOME="$TMPDIR_TEST/empty-home"
  mkdir -p "$HOME"
  run bash "$SCRIPT" status
  # Should not crash even without config
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}
