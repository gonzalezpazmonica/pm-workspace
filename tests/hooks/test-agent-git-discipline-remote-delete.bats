#!/usr/bin/env bats
# Ref: docs/rules/domain/autonomous-safety.md — NUNCA borrar ramas ajenas
#
# Un agente solo borra en el remoto sus propias ramas agent/*. Borrar cualquier otra rama remota
# (main, develop, feature/* humana) con `git push --delete`, `git push -d` o la refspec `:rama`
# requiere a la operadora. Las menciones dentro de un mensaje de commit no bloquean.

HOOK_SCRIPT=".opencode/hooks/agent-git-discipline.sh"

setup() {
  TMPDIR=$(mktemp -d)
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/$HOOK_SCRIPT"
}

teardown() {
  rm -rf "$TMPDIR"
}

run_cmd() {
  local input
  input=$(jq -nc --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}')
  run bash -c 'bash "$1" <<<"$2"' _ "$HOOK" "$input"
}

@test "target has safety flags" {
  grep -q "set -uo pipefail" "$HOOK"
}

@test "BLOCKS remote delete of main with --delete and -d" {
  run_cmd 'git push origin --delete main'
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOCKED"* ]]
  [[ "$output" == *"main"* ]]
  run_cmd 'git push -d origin develop'
  [ "$status" -eq 2 ]
}

@test "BLOCKS remote delete with the colon refspec" {
  run_cmd 'git push origin :feature/login'
  [ "$status" -eq 2 ]
  run_cmd 'git push origin :refs/heads/main'
  [ "$status" -eq 2 ]
}

@test "BLOCKS remote delete behind a separator, prefix or git -C" {
  run_cmd 'cd repo && git push origin --delete feature/ajena'
  [ "$status" -eq 2 ]
  run_cmd 'LANG=C git -C repo push --delete origin feature/ajena'
  [ "$status" -eq 2 ]
}

@test "BLOCKS a mixed delete of an agent branch and a human branch" {
  run_cmd 'git push origin --delete agent/x-20261003 feature/ajena'
  [ "$status" -eq 2 ]
}

@test "allows remote delete of own agent branches" {
  run_cmd 'git push origin --delete agent/overnight-20261003-x'
  [ "$status" -eq 0 ]
  run_cmd 'git push origin :agent/overnight-20261003-x'
  [ "$status" -eq 0 ]
  run_cmd 'git push origin :refs/heads/agent/overnight-20261003-x'
  [ "$status" -eq 0 ]
}

@test "allows ordinary pushes and refspecs with a source" {
  run_cmd 'git push -u origin agent/overnight-20261003-x'
  [ "$status" -eq 0 ]
  run_cmd 'git push origin HEAD:refs/heads/agent/overnight-20261003-x'
  [ "$status" -eq 0 ]
  run_cmd 'git push origin --tags'
  [ "$status" -eq 0 ]
}

@test "allows a commit message that mentions a remote delete" {
  run_cmd 'git commit -m "no hacer git push origin --delete main"'
  [ "$status" -eq 0 ]
}

@test "edge: empty delete without a branch name does not crash" {
  run_cmd 'git push origin --delete'
  [ "$status" -eq 0 ]
}

@test "edge: null input passes through" {
  run bash -c 'bash "$1" <<<"null"' _ "$HOOK"
  [ "$status" -eq 0 ]
}

@test "edge: zero-length refspec after colon is not a branch delete" {
  run_cmd 'git push origin :'
  [ "$status" -eq 0 ]
}
