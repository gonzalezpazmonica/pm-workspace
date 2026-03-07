#!/usr/bin/env bats
# Tests for block-force-push.sh hook

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK="$PWD/.claude/hooks/block-force-push.sh"
}

run_hook() {
  run bash -c "echo '$1' | bash '$HOOK'"
}

make_input() {
  echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}"
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
