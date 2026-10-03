#!/usr/bin/env bats
# Ref: docs/rules/domain/autonomous-safety.md — block-force-push no se esquiva con prefijos
#
# Lo que puede ir delante de `git` en una orden real (asignaciones de entorno, env/command/sudo,
# subshell, opciones globales como `git -C dir`) no debe esquivar el hook. Y una mención dentro de un
# mensaje de commit o de un echo sigue sin bloquear (por eso el patrón va anclado).

setup() {
  TMPDIR=$(mktemp -d)
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/.opencode/hooks/block-force-push.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

run_cmd() {
  local input
  input=$(jq -nc --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}')
  run bash -c "printf '%s' '$input' | bash '$HOOK'"
}

@test "target has safety flags" {
  grep -q "set -uo pipefail" "$HOOK"
}

@test "BLOCKS force push with an environment prefix" {
  run_cmd 'LANG=C git push --force origin feat'
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "BLOCKS force push through env, command and sudo" {
  run_cmd 'env git push -f origin feat'
  [ "$status" -eq 2 ]
  run_cmd 'command git push --force origin feat'
  [ "$status" -eq 2 ]
  run_cmd 'sudo git push --force origin feat'
  [ "$status" -eq 2 ]
}

@test "BLOCKS force push inside a subshell" {
  run_cmd 'echo $(git push --force origin feat)'
  [ "$status" -eq 2 ]
  run_cmd '(git push --force origin feat)'
  [ "$status" -eq 2 ]
}

@test "BLOCKS force push with global git options" {
  run_cmd 'git -C /repo push --force origin feat'
  [ "$status" -eq 2 ]
  run_cmd 'git --no-pager push -f origin feat'
  [ "$status" -eq 2 ]
}

@test "BLOCKS push to main and reset --hard with a prefix" {
  run_cmd 'LANG=C git push origin main'
  [ "$status" -eq 2 ]
  run_cmd 'git -c core.x=y push origin main'
  [ "$status" -eq 2 ]
  run_cmd 'FOO=1 git reset --hard HEAD~1'
  [ "$status" -eq 2 ]
}

@test "mention in a commit message passes" {
  run_cmd 'git commit -m "no hacer git push --force"'
  [ "$status" -eq 0 ]
}

@test "mention inside an echo passes" {
  run_cmd 'echo "LANG=C git push --force origin feat"'
  [ "$status" -eq 0 ]
}

@test "force-with-lease to a feature branch with a prefix still passes" {
  run_cmd 'LANG=C git push --force-with-lease origin feat'
  [ "$status" -eq 0 ]
}

@test "a -f of another command after the push passes" {
  run_cmd 'git push origin feat && ls -f'
  [ "$status" -eq 0 ]
}

@test "normal push with an environment prefix passes" {
  run_cmd 'LANG=C git push origin feat'
  [ "$status" -eq 0 ]
}

@test "boundary: git -C with a quoted path containing spaces is still blocked" {
  run_cmd 'git -C "/home/me/mi repo" push --force origin feat'
  [ "$status" -eq 2 ]
  [[ "$output" == *"--force-with-lease"* ]]
}

@test "large: a long chain of environment assignments is still blocked" {
  run_cmd 'A=1 B=2 C=3 D=4 E=5 F=6 git push --force origin feat'
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "edge: empty command passes" {
  run_cmd ''
  [ "$status" -eq 0 ]
}
