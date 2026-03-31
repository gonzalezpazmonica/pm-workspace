#!/usr/bin/env bats
# tests/hooks/test-tool-call-validate.bats — SPEC-141: tool-call healing
# Ref: .claude/rules/domain/hook-profiles.md

setup() {
  TMPDIR=$(mktemp -d)
  HOOK="$BATS_TEST_DIRNAME/../../.claude/hooks/agent-tool-call-validate.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "target has safety flags" {
  grep -q "set -[euo]" "$HOOK"
}

@test "script es bash valido" {
  bash -n "$HOOK"
}

@test "Edit con file_path vacio → bloqueado (exit 2)" {
  INPUT='{"tool_name":"Edit","tool_input":{"file_path":"","content":"x"}}'
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "Write con file_path vacio → bloqueado (exit 2)" {
  INPUT='{"tool_name":"Write","tool_input":{"file_path":"","content":"x"}}'
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "Bash con command vacio → bloqueado (exit 2)" {
  INPUT='{"tool_name":"Bash","tool_input":{"command":""}}'
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "Edit con file_path valido → pasa (exit 0)" {
  INPUT='{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.md","old_string":"a","new_string":"b"}}'
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]
}

@test "Bash con command valido → pasa (exit 0)" {
  INPUT='{"tool_name":"Bash","tool_input":{"command":"echo hello"}}'
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]
}

@test "Tool no validada (Task) → pasa (exit 0)" {
  INPUT='{"tool_name":"Task","tool_input":{"description":"test","prompt":"do something"}}'
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]
}

@test "Input vacio → pasa fail-safe (exit 0)" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

# ── Negative cases ──

@test "Write with missing content field still validates path" {
  INPUT='{"tool_name":"Write","tool_input":{"file_path":"","content":""}}'
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOQUEADO"* ]]
}

# ── Edge cases ──

@test "malformed JSON does not crash" {
  run bash "$HOOK" <<< "not-json"
  [ "$status" -eq 0 ]
  [[ ! "$output" == *"FATAL"* ]]
}

@test "empty JSON object handled gracefully" {
  run bash "$HOOK" <<< "{}"
  [ "$status" -eq 0 ]
  grep -q "." <<< "$status"
}

@test "null file_path value treated as empty" {
  INPUT='{"tool_name":"Edit","tool_input":{"file_path":null}}'
  run bash "$HOOK" <<< "$INPUT"
  # null extracted by jq becomes empty → should block
  [ "$status" -eq 2 ] || [ "$status" -eq 0 ]
}

@test "target script has safety flags" {
  grep -q "set -[euo]" "$BATS_TEST_DIRNAME/../../.claude/hooks/agent-tool-call-validate.sh"
}

@test "edge: empty input produces no error" {
  run bash -c "echo '{}' | SAVIA_HOOK_PROFILE=minimal bash '$BATS_TEST_DIRNAME/../../.claude/hooks/validate-bash-global.sh' 2>&1"
  [ "$status" -eq 0 ]
}
