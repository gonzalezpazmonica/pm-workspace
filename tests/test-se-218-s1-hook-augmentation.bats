#!/usr/bin/env bats
# test-se-218-s1-hook-augmentation.bats — SE-218 S1
# Ref: docs/propuestas/SE-218-codebase-memory-patterns.md
# Tests: hook augmentation pattern (Grep|Glob only, never Read, always exit 0)

setup() {
  HOOK="$BATS_TEST_DIRNAME/../.claude/hooks/ast-comprehend-hook.sh"
  export CLAUDE_PROJECT_DIR="/home/monica/savia"
}

# 1. Hook existe y es ejecutable
@test "hook exists and is executable" {
  [[ -x "$HOOK" ]]
}

# 2. set -uo pipefail en línea 2
@test "hook has set -uo pipefail on line 2" {
  run grep -n "set -uo pipefail" "$HOOK"
  [[ "$status" -eq 0 ]]
  # Debe aparecer en las primeras 3 líneas
  LINE=$(grep -n "set -uo pipefail" "$HOOK" | head -1 | cut -d: -f1)
  [[ "$LINE" -le 3 ]]
}

# 3. tool_name=Grep → exit 0 (nunca bloquea)
@test "tool_name=Grep exits 0" {
  INPUT='{"tool_name":"Grep","tool_input":{"pattern":"something","path":"/tmp"}}'
  run bash "$HOOK" <<< "$INPUT"
  [[ "$status" -eq 0 ]]
}

# 4. tool_name=Glob → exit 0 (nunca bloquea)
@test "tool_name=Glob exits 0" {
  INPUT='{"tool_name":"Glob","tool_input":{"pattern":"**/*.sh"}}'
  run bash "$HOOK" <<< "$INPUT"
  [[ "$status" -eq 0 ]]
}

# 5. tool_name=Read → exit 0 y stdout vacío (NUNCA intercepta Read — invariante crítica)
@test "tool_name=Read exits 0 with empty stdout (never intercepts Read)" {
  INPUT='{"tool_name":"Read","tool_input":{"file_path":"/tmp/test.sh"}}'
  run bash "$HOOK" <<< "$INPUT"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

# 6. tool_name=Edit → exit 0 y stdout vacío
@test "tool_name=Edit exits 0 with empty stdout" {
  INPUT='{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.sh","old_string":"x","new_string":"y"}}'
  run bash "$HOOK" <<< "$INPUT"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

# 7. tool_name=Bash → exit 0 y stdout vacío
@test "tool_name=Bash exits 0 with empty stdout" {
  INPUT='{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  run bash "$HOOK" <<< "$INPUT"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

# 8. input inválido/vacío → exit 0 (no crash)
@test "invalid or empty input exits 0 without crash" {
  run bash "$HOOK" <<< ""
  [[ "$status" -eq 0 ]]

  run bash "$HOOK" <<< "not valid json {"
  [[ "$status" -eq 0 ]]

  run bash "$HOOK" <<< "{}"
  [[ "$status" -eq 0 ]]
}

teardown() {
  true
}

@test "edge: empty CLAUDE_TOOL_INPUT env exits 0 without crash" {
  CLAUDE_TOOL_INPUT="" run bash "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
}

@test "edge: nonexistent workspace root exits 0 without crash" {
  CLAUDE_PROJECT_DIR="/nonexistent/path" \
    CLAUDE_TOOL_INPUT='{"tool_name":"Grep","tool_input":{"pattern":"foo"}}' \
    run bash "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
}

@test "assertion: output when present is valid JSON or empty" {
  CLAUDE_TOOL_INPUT='{"tool_name":"Grep","tool_input":{"pattern":"setup"}}' \
    run bash "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
  # If output non-empty, must be valid JSON
  if [[ -n "$output" ]]; then
    echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null
  fi
}
