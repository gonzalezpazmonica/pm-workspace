#!/usr/bin/env bats
# Tests for block-project-whitelist.sh Claude Code hook

setup() {
  HOOK="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.claude/hooks" && pwd)/block-project-whitelist.sh"
}

@test "hook exists and is executable" {
  [ -f "$HOOK" ]
  [ -x "$HOOK" ] || chmod +x "$HOOK"
}

@test "allows edits to non-.gitignore files" {
  run bash -c "CLAUDE_TOOL_INPUT='file_path: src/main.kt' bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "allows .gitignore edits without project whitelist" {
  run bash -c "CLAUDE_TOOL_INPUT='.gitignore adding node_modules/' bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "BLOCKS .gitignore edit with project whitelist pattern" {
  run bash -c "CLAUDE_TOOL_INPUT='.gitignore !projects/client-secret/' bash '$HOOK'"
  [ "$status" -eq 2 ]
}

@test "BLOCKS .gitignore with !projects/ anywhere in input" {
  run bash -c "CLAUDE_TOOL_INPUT='editing .gitignore to add !projects/nuevo-proyecto/' bash '$HOOK'"
  [ "$status" -eq 2 ]
}

@test "allows empty CLAUDE_TOOL_INPUT" {
  run bash -c "CLAUDE_TOOL_INPUT='' bash '$HOOK'"
  [ "$status" -eq 0 ]
}
