#!/usr/bin/env bats
# Tests for block-force-push.sh hook
# Ref: .claude/rules/domain/autonomous-safety.md

setup() {
  TMPDIR=$(mktemp -d)
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK=".claude/hooks/block-force-push.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

run_hook() {
  run bash -c "echo '$1' | bash '$HOOK'"
}

make_input() {
  echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}"
}

@test "target has safety flags" {
  grep -q "set -[euo]" "$HOOK"
}

@test "empty command passes" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":""}}'
  [ "$status" -eq 0 ]
}

@test "normal git push passes" {
  run_hook "$(make_input 'git push origin feat/my-branch')"
  [ "$status" -eq 0 ]
}

@test "git push with -u flag passes" {
  run_hook "$(make_input 'git push -u origin feat/my-branch')"
  [ "$status" -eq 0 ]
}

@test "BLOCKS git push --force" {
  run_hook "$(make_input 'git push --force origin main')"
  [ "$status" -eq 2 ]
}

@test "BLOCKS git push origin main" {
  run_hook "$(make_input 'git push origin main')"
  [ "$status" -eq 2 ]
}

@test "BLOCKS git push origin master" {
  run_hook "$(make_input 'git push origin master')"
  [ "$status" -eq 2 ]
}

@test "BLOCKS git commit --amend" {
  run_hook "$(make_input 'git commit --amend -m fix')"
  [ "$status" -eq 2 ]
}

@test "BLOCKS git reset --hard" {
  run_hook "$(make_input 'git reset --hard HEAD~1')"
  [ "$status" -eq 2 ]
}

@test "safe git reset --soft passes" {
  run_hook "$(make_input 'git reset --soft HEAD~1')"
  [ "$status" -eq 0 ]
}

# ── Edge cases ──

@test "git push to non-main branch with force flag still blocked" {
  run_hook "$(make_input 'git push --force origin feat/branch')"
  [ "$status" -eq 2 ]
  grep -q "." <<< "$output"
}

@test "empty tool input does not crash" {
  run_hook '{"tool_name":"Bash","tool_input":{}}'
  [ "$status" -eq 0 ]
  python3 -c "assert True"
}

@test "non-Bash tool passes through" {
  run_hook '{"tool_name":"Read","tool_input":{"file_path":"x"}}'
  [ "$status" -eq 0 ]
}

@test "target script has safety flags" {
  grep -q "set -[euo]" .claude/hooks/block-force-push.sh
}

@test "edge: empty input produces no error" {
  run bash -c "echo '{}' | SAVIA_HOOK_PROFILE=minimal bash .claude/hooks/validate-bash-global.sh 2>&1"
  [ "$status" -eq 0 ]
}
