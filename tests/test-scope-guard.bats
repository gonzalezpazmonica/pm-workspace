#!/usr/bin/env bats
# BATS tests for scope-guard.sh — SPEC-032 audit coverage

SCRIPT=".claude/hooks/scope-guard.sh"

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script has safety flags" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "passes with empty input" {
  echo '{}' | bash "$SCRIPT"
}

@test "passes when no spec scope is active" {
  echo '{"tool_input":{"file_path":"/tmp/test.md"}}' | bash "$SCRIPT"
}

@test "passes with Edit tool input" {
  echo '{"tool_input":{"file_path":"src/main.rs","old_string":"a","new_string":"b"}}' | bash "$SCRIPT"
}

@test "exits 0 always (warning only)" {
  result=$(echo '{"tool_input":{"file_path":"random/file.txt"}}' | bash "$SCRIPT"; echo $?)
  [[ "$result" -eq 0 ]]
}

@test "handles missing file_path gracefully" {
  echo '{"tool_input":{"command":"ls"}}' | bash "$SCRIPT"
}

@test "handles malformed JSON" {
  echo 'not json' | bash "$SCRIPT"
}
