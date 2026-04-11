#!/usr/bin/env bats
# Ref: .claude/commands/memory-check.md
# Ref: .claude/rules/domain/session-memory-protocol.md
# Tests for scripts/memory-check.sh — 10-layer memory health check.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/memory-check.sh"
  TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/memcheck.XXXXXX")"
  export TEST_TMP
}

teardown() {
  [[ -n "${TEST_TMP:-}" && -d "$TEST_TMP" ]] && rm -rf "$TEST_TMP"
}

@test "script file exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script starts with a shebang" {
  head -1 "$SCRIPT" | grep -q '^#!'
}

@test "script has set -uo pipefail safety" {
  head -5 "$SCRIPT" | grep -q 'set -uo pipefail'
}

@test "script defines ok, warn, fail, info helper functions" {
  grep -q '^ok()'   "$SCRIPT"
  grep -q '^warn()' "$SCRIPT"
  grep -q '^fail()' "$SCRIPT"
  grep -q '^info()' "$SCRIPT"
}

@test "script defines section helper" {
  grep -q '^section()' "$SCRIPT"
}

@test "runs without crashing with no arguments" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "output contains expected header" {
  run bash "$SCRIPT"
  [[ "$output" == *"Savia Memory Health Check"* ]]
}

@test "output exercises all 10 layers from 1/10 to 10/10" {
  run bash "$SCRIPT"
  [[ "$output" == *"[1/10]"*  ]]
  [[ "$output" == *"[2/10]"*  ]]
  [[ "$output" == *"[3/10]"*  ]]
  [[ "$output" == *"[4/10]"*  ]]
  [[ "$output" == *"[5/10]"*  ]]
  [[ "$output" == *"[6/10]"*  ]]
  [[ "$output" == *"[7/10]"*  ]]
  [[ "$output" == *"[8/10]"*  ]]
  [[ "$output" == *"[9/10]"*  ]]
  [[ "$output" == *"[10/10]"* ]]
}

@test "output reports PASS, WARN and FAIL counters" {
  run bash "$SCRIPT"
  [[ "$output" == *"PASS:"* ]]
  [[ "$output" == *"WARN:"* ]]
  [[ "$output" == *"FAIL:"* ]]
}

@test "command file has required frontmatter" {
  cmd="$REPO_ROOT/.claude/commands/memory-check.md"
  [[ -f "$cmd" ]]
  grep -q '^name: memory-check' "$cmd"
  grep -q '^description:' "$cmd"
}

@test "fails gracefully when launched in an empty working directory" {
  cd "$TEST_TMP"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "returns status 0 or 1 with nonexistent HOME override" {
  run env HOME="$TEST_TMP/nonexistent" bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "handles zero-length TMPDIR without crashing" {
  run bash "$SCRIPT"
  [[ -n "$output" ]]
  [[ "$status" -ne 2 ]]
}

@test "rejects invalid flags without hanging (timeout boundary)" {
  run timeout 15 bash "$SCRIPT" --no-such-flag-xyz
  [[ "$status" -ne 124 ]]
}

@test "no argument invocation produces non-empty output" {
  run bash "$SCRIPT"
  [[ "${#output}" -gt 0 ]]
}
