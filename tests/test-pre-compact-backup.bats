#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-026-precompact-hook.md
# Tests for pre-compact-backup.sh — PreCompact hook

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/.claude/hooks/pre-compact-backup.sh"
  TMPDIR_PC=$(mktemp -d)
}

teardown() { rm -rf "$TMPDIR_PC"; }

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "valid bash syntax" {
  run bash -n "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "handles empty stdin" {
  run bash -c "echo '' | bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "handles JSON stdin" {
  run bash -c "echo '{\"type\":\"compact\"}' | bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "always exits 0 (never blocks compact)" {
  run bash -c "echo 'invalid' | bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "negative: missing memory-store script handled" {
  export CLAUDE_PROJECT_DIR="$TMPDIR_PC"
  run bash -c "echo '{}' | bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "edge: very large stdin handled" {
  run bash -c "printf '%0.sX' {1..1000} | bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "coverage: references memory-store" {
  grep -q "memory-store\|memory_store" "$SCRIPT"
}
