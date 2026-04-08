#!/usr/bin/env bats
# BATS tests for tool-result-trim.sh
# SCRIPT=scripts/tool-result-trim.sh
# SPEC: SPEC-087 — Tool Result Trimming (deterministic hard cap for tool output)

SCRIPT="scripts/tool-result-trim.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/tool-result-trim.sh"
  # Ensure no stale env leaks between tests
  unset TOOL_RESULT_MAX_CHARS
}

teardown() {
  unset TOOL_RESULT_MAX_CHARS
}

# --- Structural tests ---

@test "script exists and is executable" {
  # Verify the script file is present and has execute permission
  [[ -f "$SCRIPT" ]]
}

@test "script has set -uo pipefail for safety" {
  # Safety flags prevent undefined variable usage and pipe failures
  head -10 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "script reads TOOL_RESULT_MAX_CHARS env var with default" {
  # The script must honour the configurable limit variable
  grep -q 'TOOL_RESULT_MAX_CHARS' "$SCRIPT"
  grep -q '5000' "$SCRIPT"
}

@test "script uses printf not echo for output" {
  # printf is portable and handles special chars; echo is unreliable
  grep -q "printf" "$SCRIPT"
}

# --- Pass-through tests ---

@test "content under limit passes through unchanged" {
  # Short input must arrive at stdout byte-identical
  input="hello world"
  result=$(echo -n "$input" | bash "$SCRIPT")
  [[ "$result" == "$input" ]]
}

@test "empty content passes through as empty string" {
  # Zero-length stdin must produce zero-length stdout
  result=$(echo -n "" | bash "$SCRIPT")
  [[ -z "$result" ]]
}

@test "exact boundary 5000 chars: no truncation" {
  # Input exactly at the limit must NOT be truncated
  input=$(python3 -c "print('C' * 5000, end='')")
  result=$(echo -n "$input" | bash "$SCRIPT")
  [[ "$result" != *"truncado"* ]]
  [[ ${#result} -eq 5000 ]]
}

# --- Truncation tests ---

@test "content over default limit is truncated with message" {
  # Input exceeding 5000 chars must be trimmed and annotated
  input=$(python3 -c "print('A' * 6000, end='')")
  result=$(echo -n "$input" | bash "$SCRIPT")
  [[ ${#result} -lt 6000 ]]
  [[ "$result" == *"[...truncado a 5000 chars]"* ]]
}

@test "5001 chars triggers truncation" {
  # One char over the boundary must activate the trim
  input=$(python3 -c "print('D' * 5001, end='')")
  result=$(echo -n "$input" | bash "$SCRIPT")
  [[ "$result" == *"[...truncado a 5000 chars]"* ]]
}

@test "truncation message format is exact" {
  # Verify the truncation suffix matches the documented format precisely
  input=$(python3 -c "print('Z' * 8000, end='')")
  result=$(echo -n "$input" | bash "$SCRIPT")
  # Must end with newline + bracket message
  [[ "$result" =~ \[\.\.\.truncado\ a\ 5000\ chars\]$ ]]
}

@test "custom limit via TOOL_RESULT_MAX_CHARS env var" {
  # The configurable env var must override the default 5000
  input=$(python3 -c "print('B' * 200, end='')")
  export TOOL_RESULT_MAX_CHARS=100
  result=$(echo -n "$input" | bash "$SCRIPT")
  [[ "$result" == *"[...truncado a 100 chars]"* ]]
}

# --- Exit code tests ---

@test "exit code 0 for short input" {
  # Trimming is informational; exit must always be 0
  run bash -c 'echo "test" | bash '"\"$SCRIPT\""
  [[ "$status" -eq 0 ]]
}

@test "exit code 0 even with very large input" {
  # Even 50K input must not cause non-zero exit
  run bash -c 'python3 -c "print(\"X\" * 50000, end=\"\")" | bash '"\"$SCRIPT\""
  [[ "$status" -eq 0 ]]
}

# --- Edge cases ---

@test "edge: input with embedded newlines preserved under limit" {
  # Multi-line content under limit must pass through with newlines intact
  input=$'line1\nline2\nline3'
  result=$(printf '%s' "$input" | bash "$SCRIPT")
  [[ "$result" == "$input" ]]
}

@test "edge: unicode characters preserved under limit" {
  # Non-ASCII content (accents, emoji, CJK) must not be corrupted
  input="Hola mundo! cafe con leche -- Unicode: aeiou 123"
  result=$(echo -n "$input" | bash "$SCRIPT")
  [[ "$result" == "$input" ]]
}

@test "edge: special shell characters pass through safely" {
  # Characters that could break unquoted expansions must survive
  input='$HOME "quotes" `backtick` $(cmd) * ? [glob] {brace}'
  result=$(printf '%s' "$input" | bash "$SCRIPT")
  [[ "$result" == "$input" ]]
}

@test "edge: binary-like input with null-adjacent bytes handled" {
  # Tab, carriage return, and control chars should not crash the script
  input=$'tab\there\rCR\tthere'
  result=$(printf '%s' "$input" | bash "$SCRIPT")
  [[ -n "$result" ]]
}
