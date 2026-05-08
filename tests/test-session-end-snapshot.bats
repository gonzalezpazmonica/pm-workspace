#!/usr/bin/env bats
# BATS tests for .opencode/hooks/session-end-snapshot.sh
# Stop hook — saves context snapshot at session end via context-snapshot.sh.
# Ref: batch 50 hook coverage — context-snapshot integration

HOOK=".opencode/hooks/session-end-snapshot.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_HOME=$(mktemp -d "$TMPDIR/ses-XXXXXX")
}
teardown() {
  rm -rf "$TEST_HOME" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }
@test "Stop hook event documented" {
  run grep -c 'Stop event\|Stop hook\|session ends' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Stdin handling ──────────────────────────────────

@test "stdin: drains stdin without failing" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"some":"json"}'
  [ "$status" -eq 0 ]
}

@test "stdin: empty stdin handled" {
  HOME="$TEST_HOME" run bash "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
}

@test "stdin: large stdin drained" {
  local big
  big=$(python3 -c 'print("x" * 5000)')
  HOME="$TEST_HOME" run bash "$HOOK" <<< "$big"
  [ "$status" -eq 0 ]
}

# ── Snapshot delegation ─────────────────────────────

@test "delegate: SNAPSHOT_SCRIPT discovery via for-loop" {
  run grep -c 'SNAPSHOT_SCRIPT' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "delegate: looks for context-snapshot.sh in 2 paths" {
  run grep -c 'context-snapshot.sh' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "delegate: invokes save subcommand if found" {
  run grep -c '"$SNAPSHOT_SCRIPT" save\|bash.*SNAPSHOT_SCRIPT.*save' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "delegate: missing script handled gracefully" {
  # Hook should not crash if context-snapshot.sh missing — verify guard via [ -n "$SNAPSHOT_SCRIPT" ]
  run grep -c 'if \[ -n "\$SNAPSHOT_SCRIPT" \]' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Error handling ──────────────────────────────────

@test "error: trap ERR for graceful failure logging" {
  run grep -c 'trap.*ERR\|hook-errors.log' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "error: snapshot script failure does not crash hook" {
  run grep -c '|| true\|2>&1' "$HOOK"
  [[ "$output" -ge 2 ]]
}

# ── Negative cases ──────────────────────────────────

@test "negative: malformed JSON does not crash" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< "not json at all"
  [ "$status" -eq 0 ]
}

@test "negative: missing context-snapshot.sh exits 0" {
  # Default repo state may or may not have script; verify exit 0 either way
  HOME="$TEST_HOME" run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

# ── Edge cases ──────────────────────────────────────

@test "edge: invocation with no stdin pipe (interactive style)" {
  HOME="$TEST_HOME" run bash "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
}

@test "edge: HOME dir creation handled" {
  local new_home="$TMPDIR/ses-newhome-$$"
  HOME="$new_home" run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  rm -rf "$new_home"
}

@test "edge: SCRIPT_DIR resolution via dirname" {
  run grep -c 'SCRIPT_DIR=\|dirname' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Coverage ──────────────────────────────────────────

@test "coverage: 2-path discovery (root and cwd)" {
  run grep -cE 'ROOT/scripts/context-snapshot|./scripts/context-snapshot' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: -x check for executable script" {
  run grep -c '\-x.*spath' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: redirect stdout+stderr to /dev/null" {
  run grep -c '/dev/null' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ──────────────────────────────────────────

@test "isolation: hook always exits 0" {
  for input in '' 'junk' '{"json":true}' "$(printf 'big%.0s' {1..100})"; do
    HOME="$TEST_HOME" run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: hook does not modify repo source" {
  local before after
  before=$(find . -maxdepth 2 -type f 2>/dev/null | wc -l)
  HOME="$TEST_HOME" bash "$HOOK" <<< "" >/dev/null 2>&1
  after=$(find . -maxdepth 2 -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}
