#!/usr/bin/env bats
# tests/test-se258-s1-hook.bats
# Ref: SE-258 Slice 1 — block-sensitive-tracking hook

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HOOK="$REPO_ROOT/.claude/hooks/block-sensitive-tracking.sh"
  export CLAUDE_PROJECT_DIR="$REPO_ROOT"
}

teardown() {
  true
}

@test "se258-s1: script is valid bash" {
  bash -n "$HOOK"
}

@test "se258-s1: has set -uo pipefail in first 3 lines" {
  LINE=$(grep -n "set -uo pipefail" "$HOOK" | head -1 | cut -d: -f1)
  [[ "$LINE" -le 3 ]]
}

@test "se258-s1: non-Edit tool passes (exit 0)" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  [[ "$status" -eq 0 ]]
}

@test "se258-s1: empty input exits 0" {
  run bash "$HOOK" <<< ""
  [[ "$status" -eq 0 ]]
}

@test "se258-s1: no stdin exits 0" {
  run bash "$HOOK" < /dev/null
  [[ "$status" -eq 0 ]]
}

@test "se258-s1: master switch off disables hook" {
  export SAVIA_SENSITIVE_TRACKING=off
  run bash "$HOOK" <<< '{"tool_name":"Write","tool_input":{"file_path":"data/relacion/ledger.jsonl"}}'
  [[ "$status" -eq 0 ]]
}

@test "se258-s1: regular file edit passes (exit 0)" {
  run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{"file_path":"scripts/test.sh"}}'
  [[ "$status" -eq 0 ]]
}
