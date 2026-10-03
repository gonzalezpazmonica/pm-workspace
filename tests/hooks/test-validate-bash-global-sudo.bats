#!/usr/bin/env bats
# Ref: docs/rules/domain/autonomous-safety.md — «sudo» no se esquiva encadenado, con prefijo ni en subshell
#
# El hook bloqueaba `sudo` solo al principio de la orden: `true && sudo …`, `LANG=C sudo …` o
# `echo $(sudo …)` pasaban (también en el puerto TS). Una mención dentro de un echo sigue pasando.

setup() {
  TMPDIR=$(mktemp -d)
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/.opencode/hooks/validate-bash-global.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

run_cmd() {
  local input
  input=$(jq -nc --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}')
  run bash -c "printf '%s' '$input' | CLAUDE_PROJECT_DIR='$REPO_ROOT' bash '$HOOK'"
}

@test "target has safety flags" {
  grep -q "set -uo pipefail" "$HOOK"
}

@test "BLOCKS sudo at the start (unchanged)" {
  run_cmd 'sudo apt install x'
  [ "$status" -eq 2 ]
  [[ "$output" == *"sudo"* ]]
}

@test "BLOCKS sudo after a separator" {
  run_cmd 'true && sudo apt install x'
  [ "$status" -eq 2 ]
  run_cmd 'ls; sudo rm a'
  [ "$status" -eq 2 ]
}

@test "BLOCKS sudo with an environment prefix" {
  run_cmd 'LANG=C sudo apt install x'
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "BLOCKS sudo inside a subshell" {
  run_cmd 'echo $(sudo cat /etc/shadow)'
  [ "$status" -eq 2 ]
  run_cmd '(sudo id)'
  [ "$status" -eq 2 ]
}

@test "mention inside an echo passes" {
  run_cmd 'echo "usa sudo solo con permiso"'
  [ "$status" -eq 0 ]
}

@test "a word that only contains sudo passes" {
  run_cmd 'ls pseudocode/'
  [ "$status" -eq 0 ]
}

@test "normal command with an environment prefix passes" {
  run_cmd 'LANG=C ls -la'
  [ "$status" -eq 0 ]
}

@test "boundary: sudo as the last token without arguments is still blocked" {
  run_cmd 'true && sudo'
  [ "$status" -eq 2 ]
}

@test "large: a long chain before sudo is still blocked" {
  run_cmd 'cd /tmp && ls && pwd && echo ok && sudo id'
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "edge: empty command passes" {
  run_cmd ''
  [ "$status" -eq 0 ]
}
