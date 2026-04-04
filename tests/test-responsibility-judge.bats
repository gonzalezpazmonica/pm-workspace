#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-043-responsibility-judge.md
# Tests for responsibility-judge.sh — Deterministic shortcut detector

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/.claude/hooks/responsibility-judge.sh"
  TMPDIR_RJ=$(mktemp -d)
}

teardown() { rm -rf "$TMPDIR_RJ"; }

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "valid bash syntax" {
  run bash -n "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "detects S-06 pattern in script source" {
  # Verify the hook contains S-06 TODO/FIXME detection logic
  grep -q "S-06\|TODO.*FIXME\|FIXME.*TODO" "$SCRIPT"
}

@test "passes clean input without TODO" {
  echo '{"tool":"Edit","input":{"file_path":"/test/file.sh","new_string":"clean code here"}}' > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "excludes DOMAIN.md from S-06" {
  echo '{"tool":"Write","input":{"file_path":"/test/DOMAIN.md","content":"TODO document this"}}' > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "negative: minimal profile skips checks" {
  echo '{"tool":"Edit","input":{"file_path":"/test/file.sh","new_string":"TODO fix"}}' > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=minimal bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "edge: empty stdin handled" {
  run bash -c "echo '' | bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "coverage: profile-gate sourced" {
  grep -q "profile-gate\|profile_gate" "$SCRIPT"
}
