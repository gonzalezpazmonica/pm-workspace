#!/usr/bin/env bats
# Tests for SPEC-087 — Tool Result Trimming
# Ref: scripts/tool-result-trim.sh

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/tool-result-trim.sh"
}

@test "content under limit passes through unchanged" {
  input="hello world"
  result=$(echo -n "$input" | bash "$SCRIPT")
  [[ "$result" == "$input" ]]
}

@test "content over limit is truncated with message" {
  input=$(python3 -c "print('A' * 6000, end='')")
  result=$(echo -n "$input" | bash "$SCRIPT")
  [[ ${#result} -lt 6000 ]]
  [[ "$result" == *"[...truncado a 5000 chars]"* ]]
}

@test "empty content passes through" {
  result=$(echo -n "" | bash "$SCRIPT")
  [[ -z "$result" ]]
}

@test "custom limit via TOOL_RESULT_MAX_CHARS env var" {
  input=$(python3 -c "print('B' * 200, end='')")
  result=$(echo -n "$input" | TOOL_RESULT_MAX_CHARS=100 bash "$SCRIPT")
  [[ "$result" == *"[...truncado a 100 chars]"* ]]
}

@test "exact boundary 5000 chars: no truncation" {
  input=$(python3 -c "print('C' * 5000, end='')")
  result=$(echo -n "$input" | bash "$SCRIPT")
  [[ "$result" != *"truncado"* ]]
  [[ ${#result} -eq 5000 ]]
}

@test "5001 chars: truncated" {
  input=$(python3 -c "print('D' * 5001, end='')")
  result=$(echo -n "$input" | bash "$SCRIPT")
  [[ "$result" == *"[...truncado a 5000 chars]"* ]]
}

@test "exit code always 0" {
  echo "test" | bash "$SCRIPT"
  [[ $? -eq 0 ]]
}

@test "exit code 0 even with large input" {
  python3 -c "print('X' * 50000, end='')" | bash "$SCRIPT" > /dev/null
  [[ $? -eq 0 ]]
}

@test "script has set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}
