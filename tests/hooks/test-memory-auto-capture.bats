#!/usr/bin/env bats
# Tests for memory-auto-capture.sh hook
# Auto-saves file edits to memory store. Never blocks. Rate-limited to 5 min intervals.

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK="$PWD/.claude/hooks/memory-auto-capture.sh"
  export TEST_TMPDIR="/tmp/hooktest-$$-$BATS_TEST_NUMBER"
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
  mkdir -p "$TEST_TMPDIR/scripts"
  mkdir -p "$TEST_TMPDIR/.claude/rules"
  mkdir -p "$TEST_TMPDIR/.claude/commands"
  mkdir -p "$HOME/.pm-workspace"
  cd "$TEST_TMPDIR"
  git init --quiet 2>/dev/null || true
  # Mock memory-store.sh for testing
  cat > "$TEST_TMPDIR/scripts/memory-store.sh" << 'EOF'
#!/bin/bash
# Mock memory store
exit 0
EOF
  chmod +x "$TEST_TMPDIR/scripts/memory-store.sh"
}

teardown() {
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
  rm -f "$HOME/.pm-workspace/memory-capture-last.ts"
}

run_hook() {
  local tmpf="/tmp/memory-input-$$.json"
  printf '%s' "$1" > "$tmpf"
  run bash -c "cd '$TEST_TMPDIR' && export CLAUDE_PROJECT_DIR='$TEST_TMPDIR' && export TOOL_NAME='$TOOL_NAME' && export EDITED_FILE='$EDITED_FILE' && export FILE_PATH='$FILE_PATH' && cat '$tmpf' | bash '$HOOK'"
  rm -f "$tmpf"
}

# ── Always exits 0 (never blocks) ──

@test "always exits 0" {
  export TOOL_NAME="Edit"
  export EDITED_FILE="$TEST_TMPDIR/scripts/test.sh"
  run_hook '{"tool_name":"Edit"}'
  [ "$status" -eq 0 ]
}

# ── Non-Edit/Write tool passes through ──

@test "non-Edit/Write tool passes through" {
  export TOOL_NAME="Bash"
  export EDITED_FILE=""
  run_hook '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  [ "$status" -eq 0 ]
}

# ── Handles Edit tool input ──

@test "handles Edit tool input" {
  touch "$TEST_TMPDIR/scripts/new-script.sh"
  export TOOL_NAME="Edit"
  export EDITED_FILE="$TEST_TMPDIR/scripts/new-script.sh"
  # Clear rate limit to allow capture
  rm -f "$HOME/.pm-workspace/memory-capture-last.ts"
  run_hook '{"tool_name":"Edit"}'
  [ "$status" -eq 0 ]
}

# ── Handles missing memory directory ──

@test "handles missing memory directory" {
  rm -rf "$HOME/.pm-workspace"
  touch "$TEST_TMPDIR/.claude/commands/test-cmd.md"
  export TOOL_NAME="Write"
  export EDITED_FILE="$TEST_TMPDIR/.claude/commands/test-cmd.md"
  rm -f "$HOME/.pm-workspace/memory-capture-last.ts"
  run_hook '{"tool_name":"Write"}'
  [ "$status" -eq 0 ]
  # Directory should be created
  [ -d "$HOME/.pm-workspace" ]
}

# ── Empty input passes ──

@test "empty input passes" {
  export TOOL_NAME="Edit"
  export EDITED_FILE=""
  run_hook '{"tool_name":"Edit"}'
  [ "$status" -eq 0 ]
}
