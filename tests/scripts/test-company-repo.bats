#!/usr/bin/env bats
# Tests for company-repo.sh — Company Savia repo lifecycle
# Ref: community-protocol.md

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/company-repo.sh"

setup() {
  export TMPDIR_TEST=$(mktemp -d)
  export ORIG_HOME="$HOME"
  export HOME="$TMPDIR_TEST/home"
  mkdir -p "$HOME/.pm-workspace"
}

teardown() {
  export HOME="$ORIG_HOME"
  rm -rf "$TMPDIR_TEST"
}

# ── Structure ──

@test "company-repo: script is valid bash" {
  bash -n "$SCRIPT"
}

@test "company-repo: uses set -euo pipefail" {
  grep -q "set -euo pipefail" "$SCRIPT"
}

# ── Positive cases ──

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

# ── Negative cases ──

@test "company-repo: create without args fails" {
  run bash "$SCRIPT" create
  [ "$status" -ne 0 ]
}

@test "company-repo: create with partial args fails" {
  run bash "$SCRIPT" create "http://example.com/repo"
  [ "$status" -ne 0 ]
}

# ── Edge cases ──

@test "company-repo: status without config handles gracefully" {
  export HOME="$TMPDIR_TEST/empty-home"
  mkdir -p "$HOME"
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "company-repo: help output mentions company savia" {
  run bash "$SCRIPT" help
  [[ "$output" == *"Company Savia"* ]] || [[ "$output" == *"company"* ]]
}

# ── Coverage breadth ──

@test "company-repo: savia-compat.sh dependency exists" {
  [ -f "$BATS_TEST_DIRNAME/../../scripts/savia-compat.sh" ]
}

@test "company-repo: company-repo-ops.sh dependency exists" {
  [ -f "$BATS_TEST_DIRNAME/../../scripts/company-repo-ops.sh" ]
}

@test "company-repo: company-repo-templates.sh dependency exists" {
  [ -f "$BATS_TEST_DIRNAME/../../scripts/company-repo-templates.sh" ]
}

@test "company-repo: config stored in pm-workspace dir" {
  grep -q 'pm-workspace' "$SCRIPT"
  grep -q 'CONFIG_FILE\|CONFIG_DIR' "$SCRIPT"
}

@test "company-repo: git operations reference origin" {
  grep -q 'git.*push\|git.*clone\|git.*remote' "$SCRIPT"
}
