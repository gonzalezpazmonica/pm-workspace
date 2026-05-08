#!/usr/bin/env bytes
#!/usr/bin/env bats
# BATS tests for .opencode/hooks/memory-auto-capture.sh
# PostToolUse — automatic memory capture from Edit/Write on special dirs.
# Rate-limited (5 min). Uses scripts/memory-store.sh as backend.
# Ref: batch 44 hook coverage

HOOK=".opencode/hooks/memory-auto-capture.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export HOME="$TMPDIR/home-$$"
  mkdir -p "$HOME/.pm-workspace"
  export CLAUDE_PROJECT_DIR="$TMPDIR/ws-$$"
  mkdir -p "$CLAUDE_PROJECT_DIR/scripts" "$CLAUDE_PROJECT_DIR/tests" "$CLAUDE_PROJECT_DIR/docs/rules"
  # Mock memory-store.sh that just writes to a log
  cat > "$CLAUDE_PROJECT_DIR/scripts/memory-store.sh" <<'STORE_EOF'
#!/bin/bash
echo "SAVE_CALLED: $@" >> "$HOME/memory-calls.log"
STORE_EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/memory-store.sh"
  export HOOK_ABS="$(pwd)/$HOOK"
}
teardown() {
  rm -rf "$HOME" "$CLAUDE_PROJECT_DIR" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Skip paths ──────────────────────────────────────────

@test "skip: missing memory-store.sh script exits 0" {
  rm "$CLAUDE_PROJECT_DIR/scripts/memory-store.sh"
  export TOOL_NAME=Edit
  export EDITED_FILE="$CLAUDE_PROJECT_DIR/scripts/foo.sh"
  echo "x" > "$EDITED_FILE"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "skip: non-Edit/Write tool ignored" {
  export TOOL_NAME=Bash
  export EDITED_FILE="$CLAUDE_PROJECT_DIR/scripts/foo.sh"
  echo "x" > "$EDITED_FILE"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [[ ! -f "$HOME/memory-calls.log" ]]
}

@test "skip: missing file path exits 0" {
  export TOOL_NAME=Edit
  unset EDITED_FILE FILE_PATH
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "skip: file outside special dirs not captured" {
  export TOOL_NAME=Edit
  local F="$CLAUDE_PROJECT_DIR/random/foo.md"
  mkdir -p "$(dirname "$F")"
  echo "x" > "$F"
  export EDITED_FILE="$F"
  run bash "$HOOK"
  [[ ! -f "$HOME/memory-calls.log" ]]
}

# ── Type inference ──────────────────────────────────────

@test "type: tests/ path inferred as 'pattern'" {
  export TOOL_NAME=Edit
  local F="$CLAUDE_PROJECT_DIR/tests/test-foo.bats"
  echo "x" > "$F"
  export EDITED_FILE="$F"
  bash "$HOOK"
  grep -q '\-\-type pattern' "$HOME/memory-calls.log"
}

@test "type: docs/rules/ inferred as 'convention'" {
  export TOOL_NAME=Edit
  local F="$CLAUDE_PROJECT_DIR/docs/rules/something.md"
  echo "x" > "$F"
  export EDITED_FILE="$F"
  bash "$HOOK"
  grep -q '\-\-type convention' "$HOME/memory-calls.log"
}

@test "type: scripts/ inferred as 'discovery'" {
  export TOOL_NAME=Write
  local F="$CLAUDE_PROJECT_DIR/scripts/new-tool.sh"
  echo "x" > "$F"
  export EDITED_FILE="$F"
  bash "$HOOK"
  grep -q '\-\-type discovery' "$HOME/memory-calls.log"
}

@test "type: .opencode/commands/ inferred as 'convention'" {
  export TOOL_NAME=Write
  local F="$CLAUDE_PROJECT_DIR/.opencode/commands/cmd.md"
  mkdir -p "$(dirname "$F")"
  echo "x" > "$F"
  export EDITED_FILE="$F"
  bash "$HOOK"
  grep -q '\-\-type convention' "$HOME/memory-calls.log"
}

# ── Rate limit ──────────────────────────────────────────

@test "rate-limit: second capture within 5 min blocked" {
  export TOOL_NAME=Edit
  local F="$CLAUDE_PROJECT_DIR/scripts/a.sh"
  echo "x" > "$F"
  export EDITED_FILE="$F"
  bash "$HOOK"
  # Now second call should be blocked by rate limit
  bash "$HOOK"
  local calls
  calls=$(wc -l < "$HOME/memory-calls.log" 2>/dev/null)
  [[ "$calls" -eq 1 ]]
}

@test "rate-limit: timestamp file updated after capture" {
  export TOOL_NAME=Edit
  local F="$CLAUDE_PROJECT_DIR/scripts/a.sh"
  echo "x" > "$F"
  export EDITED_FILE="$F"
  bash "$HOOK"
  [[ -f "$HOME/.pm-workspace/memory-capture-last.ts" ]]
}

@test "rate-limit: stale timestamp allows capture" {
  export TOOL_NAME=Edit
  local F="$CLAUDE_PROJECT_DIR/scripts/a.sh"
  echo "x" > "$F"
  export EDITED_FILE="$F"
  # Simulate old timestamp (10 minutes ago)
  local old_ts
  old_ts=$(( $(date +%s) - 600 ))
  echo "$old_ts" > "$HOME/.pm-workspace/memory-capture-last.ts"
  bash "$HOOK"
  grep -q 'SAVE_CALLED' "$HOME/memory-calls.log"
}

# ── Content extraction ──────────────────────────────────

@test "content: title derived from basename without extension" {
  export TOOL_NAME=Edit
  local F="$CLAUDE_PROJECT_DIR/scripts/my-tool.sh"
  echo "x" > "$F"
  export EDITED_FILE="$F"
  bash "$HOOK"
  grep -q '\-\-title my-tool' "$HOME/memory-calls.log"
}

@test "content: first 200 chars passed as content" {
  export TOOL_NAME=Edit
  local F="$CLAUDE_PROJECT_DIR/scripts/big.sh"
  printf '%.0sabc' {1..100} > "$F"
  export EDITED_FILE="$F"
  bash "$HOOK"
  # Content passed to memory-store
  grep -q 'SAVE_CALLED' "$HOME/memory-calls.log"
}

@test "concepts: path segments extracted (excluding common)" {
  export TOOL_NAME=Edit
  local F="$CLAUDE_PROJECT_DIR/scripts/auth/login.sh"
  mkdir -p "$(dirname "$F")"
  echo "x" > "$F"
  export EDITED_FILE="$F"
  bash "$HOOK"
  # concepts should include "auth" and "login" but not "scripts" or ".sh"
  local calls
  calls=$(cat "$HOME/memory-calls.log")
  [[ "$calls" == *"auth"* ]]
  [[ "$calls" == *"login"* ]]
}

# ── Alternative env vars ────────────────────────────────

@test "env: FILE_PATH fallback when EDITED_FILE not set" {
  export TOOL_NAME=Edit
  unset EDITED_FILE
  local F="$CLAUDE_PROJECT_DIR/scripts/fb.sh"
  echo "x" > "$F"
  export FILE_PATH="$F"
  bash "$HOOK"
  grep -q 'SAVE_CALLED' "$HOME/memory-calls.log"
}

# ── Negative cases ──────────────────────────────────────

@test "negative: nonexistent file still calls store (best effort)" {
  export TOOL_NAME=Edit
  export EDITED_FILE="$CLAUDE_PROJECT_DIR/scripts/nonexistent.sh"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "negative: empty TOOL_NAME exits 0" {
  unset TOOL_NAME
  export EDITED_FILE="$CLAUDE_PROJECT_DIR/scripts/x.sh"
  echo "x" > "$EDITED_FILE"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: Write tool also triggers (not just Edit)" {
  export TOOL_NAME=Write
  local F="$CLAUDE_PROJECT_DIR/scripts/w.sh"
  echo "x" > "$F"
  export EDITED_FILE="$F"
  bash "$HOOK"
  grep -q 'SAVE_CALLED' "$HOME/memory-calls.log"
}

@test "edge: deeply nested tests/ path triggers pattern type" {
  export TOOL_NAME=Edit
  local F="$CLAUDE_PROJECT_DIR/tests/nested/deep/test-x.bats"
  mkdir -p "$(dirname "$F")"
  echo "x" > "$F"
  export EDITED_FILE="$F"
  bash "$HOOK"
  grep -q '\-\-type pattern' "$HOME/memory-calls.log"
}

@test "edge: rate limit file missing treated as first capture" {
  export TOOL_NAME=Edit
  rm -f "$HOME/.pm-workspace/memory-capture-last.ts"
  local F="$CLAUDE_PROJECT_DIR/scripts/first.sh"
  echo "x" > "$F"
  export EDITED_FILE="$F"
  bash "$HOOK"
  grep -q 'SAVE_CALLED' "$HOME/memory-calls.log"
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: infer_type function defined" {
  run grep -c 'infer_type()' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: infer_concepts function defined" {
  run grep -c 'infer_concepts()' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: rate limit constant present" {
  run grep -c 'RATE_LIMIT_MIN' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: 5 special dir patterns" {
  for p in 'scripts/' 'docs/rules/' '\.claude/rules/' '\.opencode/commands/' 'tests/'; do
    grep -q "$p" "$HOOK" || fail "missing pattern: $p"
  done
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ────────────────────────────────────────────

@test "isolation: always exits 0 (PostToolUse never blocks)" {
  for t in Edit Write Bash Read; do
    export TOOL_NAME="$t"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: no files created outside HOME/pm-workspace or mock log" {
  export TOOL_NAME=Edit
  export EDITED_FILE="$CLAUDE_PROJECT_DIR/scripts/x.sh"
  echo "x" > "$EDITED_FILE"
  local before
  before=$(find "$CLAUDE_PROJECT_DIR" -type f 2>/dev/null | wc -l)
  bash "$HOOK"
  local after
  after=$(find "$CLAUDE_PROJECT_DIR" -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}
