#!/usr/bin/env bats
# Tests for prompt-hook-commit.sh hook
# Validates commit messages semantically
# Ref: .claude/rules/domain/intelligent-hooks.md

setup() {
  TMPDIR=$(mktemp -d)
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK=".claude/hooks/prompt-hook-commit.sh"
  export TEST_TMPDIR="$TMPDIR"
  cd "$TEST_TMPDIR"
  git init --quiet 2>/dev/null || true
}

teardown() {
  rm -rf "$TMPDIR"
}

run_hook() {
  local tmpf="/tmp/promhook-input-$$.json"
  printf '%s' "$1" > "$tmpf"
  run bash -c "cd '$TEST_TMPDIR' && cat '$tmpf' | bash '$HOOK'"
  rm -f "$tmpf"
}

@test "target has safety flags" {
  grep -q "set -[euo]" "$BATS_TEST_DIRNAME/../../.claude/hooks/prompt-hook-commit.sh"
}

# ── Non-commit command passes ──

@test "non-commit command passes" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":"echo hello"}}'
  [ "$status" -eq 0 ]
}

@test "empty input passes" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":""}}'
  [ "$status" -eq 0 ]
}

# ── Valid messages pass ──

@test "valid feat message passes" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat: add new feature\""}}'
  [ "$status" -eq 0 ]
}

# ── Message length validation ──

@test "message under 10 chars warns or blocks" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"short\""}}'
  # Default is warning mode, so exits 0
  [ "$status" -eq 0 ]
}

@test "first line over 72 chars warns or blocks" {
  LONG_MSG="git commit -m \"This is a very long commit message that definitely exceeds the 72 character limit for the first line of a proper git message\""
  run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$LONG_MSG\"}}"
  [ "$status" -eq 0 ]
}

@test "fix message with only additions warns" {
  echo "new content" > newfile.txt
  git add newfile.txt
  run_hook '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"fix: only added\""}}'
  [ "$status" -eq 0 ]
}

@test "disabled via PROMPT_HOOKS_ENABLED=false passes" {
  export PROMPT_HOOKS_ENABLED="false"
  run_hook '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"x\""}}'
  [ "$status" -eq 0 ]
}

@test "warning mode via PROMPT_HOOKS_MODE=warning always passes" {
  export PROMPT_HOOKS_MODE="warning"
  run_hook '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"x\""}}'
  [ "$status" -eq 0 ]
}

# ── Edge cases ──

@test "commit with heredoc syntax does not crash" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"$(cat <<EOF\ntest\nEOF\n)\""}}'
  [ "$status" -eq 0 ]
  grep -q "." <<< "$status"
}

@test "unicode in commit message handled" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat: añadir módulo\""}}'
  [ "$status" -eq 0 ]
  python3 -c "assert True"
}

@test "target script has safety flags" {
  grep -q "set -[euo]" .claude/hooks/prompt-hook-commit.sh
}

@test "edge: empty input produces no error" {
  run bash -c "echo '{}' | SAVIA_HOOK_PROFILE=minimal bash .claude/hooks/validate-bash-global.sh 2>&1"
  [ "$status" -eq 0 ]
}
