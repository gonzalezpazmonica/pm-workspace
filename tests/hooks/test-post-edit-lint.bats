#!/usr/bin/env bats
# Tests for post-edit-lint.sh hook
# Auto-lints edited files by extension. Never blocks.

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK="$PWD/.claude/hooks/post-edit-lint.sh"
  export TEST_TMPDIR="/tmp/hooktest-$$-$BATS_TEST_NUMBER"
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
  mkdir -p "$TEST_TMPDIR/src"
  cd "$TEST_TMPDIR"
  git init --quiet 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

run_hook() {
  local tmpf="/tmp/lint-input-$$.json"
  printf '%s' "$1" > "$tmpf"
  run bash -c "cd '$TEST_TMPDIR' && cat '$tmpf' | bash '$HOOK'"
  rm -f "$tmpf"
}

make_input() {
  echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$1\"}}"
}

# ── Always exits 0 (never blocks) ──

@test "always exits 0" {
  run_hook "$(make_input "$TEST_TMPDIR/src/test.py")"
  [ "$status" -eq 0 ]
}

# ── Handles .py file input ──

@test "handles .py file input" {
  cat > "$TEST_TMPDIR/src/module.py" << 'EOF'
def hello():
    print("hello")
EOF
  run_hook "$(make_input "$TEST_TMPDIR/src/module.py")"
  [ "$status" -eq 0 ]
}

# ── Handles .ts file input ──

@test "handles .ts file input" {
  cat > "$TEST_TMPDIR/src/service.ts" << 'EOF'
export class Service {
  method() {}
}
EOF
  run_hook "$(make_input "$TEST_TMPDIR/src/service.ts")"
  [ "$status" -eq 0 ]
}

# ── Handles unknown extension ──

@test "handles unknown extension" {
  cat > "$TEST_TMPDIR/src/file.xyz" << 'EOF'
random content
EOF
  run_hook "$(make_input "$TEST_TMPDIR/src/file.xyz")"
  [ "$status" -eq 0 ]
}

# ── Handles .jsx file input ──

@test "handles .jsx file input" {
  cat > "$TEST_TMPDIR/src/Component.jsx" << 'EOF'
function Component() {
  return <div>Hello</div>;
}
EOF
  run_hook "$(make_input "$TEST_TMPDIR/src/Component.jsx")"
  [ "$status" -eq 0 ]
}

# ── Handles .go file input ──

@test "handles .go file input" {
  cat > "$TEST_TMPDIR/src/main.go" << 'EOF'
package main

func main() {}
EOF
  run_hook "$(make_input "$TEST_TMPDIR/src/main.go")"
  [ "$status" -eq 0 ]
}

# ── Handles .rs file input ──

@test "handles .rs file input" {
  cat > "$TEST_TMPDIR/src/lib.rs" << 'EOF'
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
EOF
  run_hook "$(make_input "$TEST_TMPDIR/src/lib.rs")"
  [ "$status" -eq 0 ]
}

# ── Empty input passes ──

@test "empty input passes" {
  run_hook '{"tool_name":"Edit","tool_input":{}}'
  [ "$status" -eq 0 ]
}
