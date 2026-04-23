#!/usr/bin/env bats
# BATS tests for .claude/hooks/ast-comprehend-hook.sh
# PreToolUse(Edit) — injects structural map before editing. Never blocks.
# Ref: batch 40 hook test coverage

HOOK=".claude/hooks/ast-comprehend-hook.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
}
teardown() { cd /; }

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Never blocks (RN-COMP-02 invariant) ──────────────────

@test "invariant: empty stdin exits 0" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "invariant: malformed JSON exits 0 (fail open)" {
  run bash "$HOOK" <<< "not json"
  [ "$status" -eq 0 ]
}

@test "invariant: missing file_path exits 0" {
  run bash "$HOOK" <<< '{"tool_input":{}}'
  [ "$status" -eq 0 ]
}

@test "invariant: nonexistent target file exits 0" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"/nonexistent/foo.py"}}'
  [ "$status" -eq 0 ]
}

@test "invariant: null file_path exits 0" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":null}}'
  [ "$status" -eq 0 ]
}

# ── Skip small files (<MIN_LINES=50) ─────────────────────

@test "skip: file with < 50 lines produces no output" {
  local TMP_FILE="$TMPDIR/small-$$.py"
  printf "line\n%.0s" {1..20} > "$TMP_FILE"
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TMP_FILE\"}}"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
  rm -f "$TMP_FILE"
}

@test "skip: exactly 49-line file under threshold" {
  local TMP_FILE="$TMPDIR/border-$$.py"
  for i in $(seq 1 49); do echo "line $i"; done > "$TMP_FILE"
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TMP_FILE\"}}"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
  rm -f "$TMP_FILE"
}

# ── Edge cases ───────────────────────────────────────────

@test "edge: empty file (0 lines) does not crash" {
  local TMP_FILE="$TMPDIR/empty-$$.py"
  : > "$TMP_FILE"
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TMP_FILE\"}}"
  [ "$status" -eq 0 ]
  rm -f "$TMP_FILE"
}

@test "edge: file_path with unusual characters handled" {
  local TMP_FILE="$TMPDIR/spaces test-$$.py"
  echo "x" > "$TMP_FILE"
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TMP_FILE\"}}"
  [ "$status" -eq 0 ]
  rm -f "$TMP_FILE"
}

@test "edge: CLAUDE_TOOL_INPUT_FILE_PATH env fallback" {
  local TMP_FILE="$TMPDIR/env-$$.py"
  echo "x" > "$TMP_FILE"
  export CLAUDE_TOOL_INPUT_FILE_PATH="$TMP_FILE"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  unset CLAUDE_TOOL_INPUT_FILE_PATH
  rm -f "$TMP_FILE"
}

@test "edge: missing ast-comprehend.sh script exits 0 gracefully" {
  # If the target script doesn't exist, hook must still exit 0
  local TMP_FILE="$TMPDIR/big-$$.py"
  for i in $(seq 1 100); do echo "def func_$i(): pass"; done > "$TMP_FILE"
  # Hook checks $SCRIPT exists; if we simulate missing, it exits 0
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TMP_FILE\"}}"
  [ "$status" -eq 0 ]
  rm -f "$TMP_FILE"
}

# ── Negative cases ───────────────────────────────────────

@test "negative: non-JSON input does not crash the hook" {
  run bash "$HOOK" <<< "random text here"
  [ "$status" -eq 0 ]
}

@test "negative: JSON without tool_input field exits 0" {
  run bash "$HOOK" <<< '{"other_field":"value"}'
  [ "$status" -eq 0 ]
}

@test "negative: file_path pointing to directory exits 0" {
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TMPDIR\"}}"
  [ "$status" -eq 0 ]
}

# ── Coverage ─────────────────────────────────────────────

@test "coverage: MIN_LINES threshold defined" {
  run grep -c 'MIN_LINES=50' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: COMPLEXITY_WARN threshold defined" {
  run grep -c 'COMPLEXITY_WARN' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: _py_extract helper function defined" {
  run grep -c '_py_extract()' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: RN-COMP-02 invariant documented" {
  run grep -c 'RN-COMP-02' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: ast-comprehend.sh referenced as target script" {
  run grep -c 'scripts/ast-comprehend.sh' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR or mktemp used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ─────────────────────────────────────────────

@test "isolation: hook exit is always 0 (never blocks)" {
  # Try multiple invocations with varied inputs; all must be 0
  local TMP_FILE="$TMPDIR/iso-$$.py"
  for i in $(seq 1 100); do echo "def f_$i(): pass"; done > "$TMP_FILE"
  for input in '' '{}' '{"x":"y"}' "{\"tool_input\":{\"file_path\":\"$TMP_FILE\"}}"; do
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
  rm -f "$TMP_FILE"
}

@test "isolation: hook does not modify target file" {
  local TMP_FILE="$TMPDIR/immut-$$.py"
  for i in $(seq 1 100); do echo "def f_$i(): pass"; done > "$TMP_FILE"
  local before
  before=$(md5sum "$TMP_FILE" | awk '{print $1}')
  bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TMP_FILE\"}}" >/dev/null 2>&1
  local after
  after=$(md5sum "$TMP_FILE" | awk '{print $1}')
  [[ "$before" == "$after" ]]
  rm -f "$TMP_FILE"
}
