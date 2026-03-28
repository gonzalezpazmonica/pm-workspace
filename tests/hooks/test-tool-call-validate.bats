#!/usr/bin/env bats
# tests/hooks/test-tool-call-validate.bats — SPEC-141: tool-call healing

HOOK="$BATS_TEST_DIRNAME/../../.claude/hooks/agent-tool-call-validate.sh"

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
