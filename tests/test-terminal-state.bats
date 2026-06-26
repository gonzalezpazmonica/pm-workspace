#!/usr/bin/env bats
# tests/test-terminal-state.bats
# Spec: SPEC-TERMINAL-STATE-HANDOFF
# Ref:  docs/rules/domain/terminal-state-protocol.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export EMIT="$REPO_ROOT/scripts/terminal-state-emit.sh"
  export READ="$REPO_ROOT/scripts/terminal-state-read.sh"

  # Isolated tmpdir per test
  TMPDIR_TS="$(mktemp -d)"
  export SAVIA_REPO_ROOT="$TMPDIR_TS"

  # Pre-create output dir skeleton (scripts create subdirs themselves)
  mkdir -p "$TMPDIR_TS/output"
}

teardown() {
  rm -rf "$TMPDIR_TS"
}

# ── emit: exit codes ──────────────────────────────────────────────────────────

@test "emit completed → exit 0" {
  run bash "$EMIT" completed --loop test-loop
  [ "$status" -eq 0 ]
}

@test "emit user_abort → exit 0" {
  run bash "$EMIT" user_abort --loop test-loop
  [ "$status" -eq 0 ]
}

@test "emit token_budget → exit 2" {
  run bash "$EMIT" token_budget --loop test-loop
  [ "$status" -eq 2 ]
}

@test "emit stop_hook → exit 3" {
  run bash "$EMIT" stop_hook --loop test-loop
  [ "$status" -eq 3 ]
}

@test "emit max_turns → exit 4" {
  run bash "$EMIT" max_turns --loop test-loop
  [ "$status" -eq 4 ]
}

@test "emit unrecoverable_error → exit 5" {
  run bash "$EMIT" unrecoverable_error --loop test-loop
  [ "$status" -eq 5 ]
}

# ── emit: JSON output validity ────────────────────────────────────────────────

@test "emit writes valid JSON to stdout" {
  run bash "$EMIT" completed --loop test-loop --message "all done"
  [ "$status" -eq 0 ]
  # Must contain the key fields
  [[ "$output" == *'"reason":"completed"'* ]]
  [[ "$output" == *'"loop":"test-loop"'* ]]
  [[ "$output" == *'"message":"all done"'* ]]
  [[ "$output" == *'"exit_code":0'* ]]
  [[ "$output" == *'"ts":"'* ]]
}

@test "emit JSON has all required fields" {
  run bash "$EMIT" token_budget --loop my-loop --message "ctx 95%"
  [ "$status" -eq 2 ]
  [[ "$output" == *'"ts":'* ]]
  [[ "$output" == *'"loop":'* ]]
  [[ "$output" == *'"reason":'* ]]
  [[ "$output" == *'"message":'* ]]
  [[ "$output" == *'"exit_code":'* ]]
}

# ── emit: jsonl persistence ───────────────────────────────────────────────────

@test "emit appends JSON line to terminal-state.jsonl" {
  bash "$EMIT" completed --loop persist-loop --message "done" || true
  STATE_FILE="$TMPDIR_TS/output/loop-state/persist-loop/terminal-state.jsonl"
  [ -f "$STATE_FILE" ]
  LINE_COUNT=$(wc -l < "$STATE_FILE")
  [ "$LINE_COUNT" -eq 1 ]
}

@test "multiple emits append multiple lines to jsonl" {
  bash "$EMIT" completed   --loop multi-loop || true
  bash "$EMIT" token_budget --loop multi-loop || true
  bash "$EMIT" max_turns    --loop multi-loop || true
  STATE_FILE="$TMPDIR_TS/output/loop-state/multi-loop/terminal-state.jsonl"
  [ -f "$STATE_FILE" ]
  LINE_COUNT=$(wc -l < "$STATE_FILE")
  [ "$LINE_COUNT" -eq 3 ]
}

# ── read: basic behavior ──────────────────────────────────────────────────────

@test "read outputs last line of jsonl" {
  bash "$EMIT" completed    --loop read-loop --message "first"  || true
  bash "$EMIT" token_budget --loop read-loop --message "second" || true

  run bash "$READ" --loop read-loop
  [ "$status" -eq 2 ]
  [[ "$output" == *'"reason":"token_budget"'* ]]
  [[ "$output" == *'"message":"second"'* ]]
}

@test "read returns exit code matching last reason" {
  bash "$EMIT" unrecoverable_error --loop ec-loop --message "crash" || true

  run bash "$READ" --loop ec-loop
  [ "$status" -eq 5 ]
}

@test "read with multiple emits always returns last entry" {
  bash "$EMIT" token_budget --loop last-loop --message "a" || true
  bash "$EMIT" completed    --loop last-loop --message "b" || true

  run bash "$READ" --loop last-loop
  # last emit was completed → exit 0
  [ "$status" -eq 0 ]
  [[ "$output" == *'"reason":"completed"'* ]]
  [[ "$output" == *'"message":"b"'* ]]
}

# ── unknown reason ────────────────────────────────────────────────────────────

@test "emit with unknown reason exits 1 and prints error" {
  run bash "$EMIT" bogus_reason --loop err-loop
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown termination reason"* ]] || \
  [[ "${lines[*]}" == *"unknown termination reason"* ]]
}

# ── read: missing state file ──────────────────────────────────────────────────

@test "read with no existing jsonl exits 1 with error message" {
  run bash "$READ" --loop nonexistent-loop
  [ "$status" -eq 1 ]
}

# ── default loop name ─────────────────────────────────────────────────────────

@test "emit without --loop uses default loop name in JSON" {
  run bash "$EMIT" completed --message "no loop arg"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"loop":"default"'* ]]
}

# ── New cases ─────────────────────────────────────────────────────────────────

@test "emit --message with newline literal -> output is valid JSON" {
  run bash "$EMIT" completed --loop newline-loop --message $'line1\nline2'
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "read JSONL with trailing blank line -> exit 1 with parse error" {
  # Write a valid line followed by a blank line (tail -n 1 reads the blank)
  local state_dir="$TMPDIR_TS/output/loop-state/trail-loop"
  mkdir -p "$state_dir"
  printf '{"ts":"2026-01-01T00:00:00Z","loop":"trail-loop","reason":"completed","message":"","exit_code":0}\n\n' \
    > "$state_dir/terminal-state.jsonl"

  run bash "$READ" --loop trail-loop
  [ "$status" -eq 1 ]
  [[ "${output}${lines[*]}" == *"parse"* ]]
}

@test "path traversal in --loop name -> exit 2, stderr contains 'must not contain'" {
  local bad_loop="../bad-path"
  run bash "$EMIT" completed --loop "$bad_loop"
  [ "$status" -eq 2 ]
  [[ "${output}${lines[*]}" == *"must not contain"* ]]
}

@test "read idempotency: reading the same file twice produces the same output" {
  bash "$EMIT" completed --loop idem-loop --message "stable" || true
  run bash "$READ" --loop idem-loop
  local first_output="$output"
  run bash "$READ" --loop idem-loop
  [ "$output" = "$first_output" ]
}

@test "emit without --loop creates file at output/loop-state/default/terminal-state.jsonl" {
  run bash "$EMIT" completed --message "default path test"
  [ "$status" -eq 0 ]
  local state_file="$TMPDIR_TS/output/loop-state/default/terminal-state.jsonl"
  [ -f "$state_file" ]
}
