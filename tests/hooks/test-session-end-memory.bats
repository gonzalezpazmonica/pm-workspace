#!/usr/bin/env bats
# tests/hooks/test-session-end-memory.bats — SPEC-013: fast session-end extraction

HOOK="$BATS_TEST_DIRNAME/../../.claude/hooks/session-end-memory.sh"

setup() {
  export TMPDIR_TEST="$BATS_TEST_TMPDIR/session-end-$$"
  mkdir -p "$TMPDIR_TEST"
  export HOME="$TMPDIR_TEST"
  export CLAUDE_PROJECT_DIR="$TMPDIR_TEST/project"
  mkdir -p "$CLAUDE_PROJECT_DIR" "$HOME/.savia"
  PROJ_SLUG=$(echo "$CLAUDE_PROJECT_DIR" | sed 's|[/:\]|-|g; s|^-||')
  export MEMORY_DIR="$HOME/.claude/projects/$PROJ_SLUG/memory"
  mkdir -p "$MEMORY_DIR"
  # Enable standard profile so hook logic runs
  export SAVIA_HOOK_PROFILE="standard"
  # Create a minimal git repo for git operations
  git -C "$CLAUDE_PROJECT_DIR" init -q 2>/dev/null || true
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "script is valid bash" {
  bash -n "$HOOK"
}

@test "script uses set -uo pipefail" {
  head -5 "$HOOK" | grep -q "set -uo pipefail"
}

@test "creates session-hot.md when action-log exists" {
  local log="$HOME/.savia/session-actions.jsonl"
  echo '{"action":"build","attempt":1,"ts":"2026-04-03T10:00:00Z"}' > "$log"
  echo '{"action":"test","attempt":2,"ts":"2026-04-03T10:01:00Z"}' >> "$log"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  [ -f "$MEMORY_DIR/session-hot.md" ]
}

@test "includes failure count from action log" {
  local log="$HOME/.savia/session-actions.jsonl"
  echo '{"action":"deploy","attempt":2,"ts":"2026-04-03T10:00:00Z"}' > "$log"
  echo '{"action":"build","attempt":3,"ts":"2026-04-03T10:01:00Z"}' >> "$log"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  grep -q "Failures: 2" "$MEMORY_DIR/session-hot.md"
}

@test "includes last actions from action log" {
  local log="$HOME/.savia/session-actions.jsonl"
  echo '{"action":"compile-service","attempt":1}' > "$log"
  echo '{"action":"run-tests","attempt":1}' >> "$log"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  grep -q "compile-service" "$MEMORY_DIR/session-hot.md"
}

@test "includes modified files from git" {
  # Create a tracked file and modify it
  echo "initial" > "$CLAUDE_PROJECT_DIR/test.txt"
  git -C "$CLAUDE_PROJECT_DIR" -c user.name="Test" -c user.email="t@t.com" add test.txt 2>/dev/null
  git -C "$CLAUDE_PROJECT_DIR" -c user.name="Test" -c user.email="t@t.com" commit -m "init" -q 2>/dev/null
  echo "modified" > "$CLAUDE_PROJECT_DIR/test.txt"
  echo '{"action":"edit","attempt":1}' > "$HOME/.savia/session-actions.jsonl"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  grep -q "Files modified:" "$MEMORY_DIR/session-hot.md"
}

@test "handles missing action-log gracefully" {
  rm -f "$HOME/.savia/session-actions.jsonl"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "never exits non-zero" {
  # Even with completely broken environment
  export CLAUDE_PROJECT_DIR="/nonexistent/path/$$"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}
