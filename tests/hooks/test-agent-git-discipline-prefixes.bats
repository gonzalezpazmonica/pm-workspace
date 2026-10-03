#!/usr/bin/env bats
# Ref: docs/rules/domain/autonomous-safety.md — agent-git-discipline no se esquiva encadenando
#
# Lo que puede ir delante de una orden real (`&&`, `;`, asignaciones de entorno, env/command/sudo,
# subshell, opciones globales como `git -C dir`) no debe esquivar el hook. Las exenciones (-i,
# dry-run, rutas seguras) valen solo para su propia orden, no para toda la línea. Y una mención
# dentro de un mensaje de commit o de un echo sigue sin bloquear.

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

@test "BLOCKS recursive rm after && and ;" {
  run_cmd 'true && rm -rf build'
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOCKED"* ]]
  run_cmd 'ls; rm -r build'
  [ "$status" -eq 2 ]
}

@test "BLOCKS recursive rm with an environment prefix and in a subshell" {
  run_cmd 'LANG=C rm -rf build'
  [ "$status" -eq 2 ]
  run_cmd 'echo $(rm -rf build)'
  [ "$status" -eq 2 ]
  run_cmd 'env command rm -fr build'
  [ "$status" -eq 2 ]
}

@test "BLOCKS rm without -i when another rm in the line has -i" {
  run_cmd 'rm -i a.txt && rm -rf build'
  [ "$status" -eq 2 ]
  run_cmd 'rm -i a.txt; rm b.txt'
  [ "$status" -eq 2 ]
}

@test "BLOCKS rm outside safe paths even when a safe path appears elsewhere" {
  run_cmd 'ls /tmp/opencode && rm notas.md'
  [ "$status" -eq 2 ]
}

@test "BLOCKS truncation, dd and mkfs behind a separator or prefix" {
  run_cmd 'true && : > ~/.bashrc'
  [ "$status" -eq 2 ]
  run_cmd 'LANG=C dd if=/dev/zero of=/dev/sda'
  [ "$status" -eq 2 ]
  run_cmd 'echo $(mkfs.ext4 /dev/sdb1)'
  [ "$status" -eq 2 ]
  run_cmd 'true && chown -R nobody /home/x'
  [ "$status" -eq 2 ]
}

@test "BLOCKS destructive git after cd && and with git -C" {
  run_cmd 'cd repo && git clean -fdx'
  [ "$status" -eq 2 ]
  run_cmd 'cd repo && git reset --hard HEAD~3'
  [ "$status" -eq 2 ]
  run_cmd 'git -C repo stash'
  [ "$status" -eq 2 ]
  run_cmd 'echo $(git checkout .)'
  [ "$status" -eq 2 ]
}

@test "BLOCKS git checkout -- . like git checkout ." {
  run_cmd 'git checkout -- .'
  [ "$status" -eq 2 ]
}

@test "BLOCKS git clean -fdx when a dry-run clean precedes it" {
  run_cmd 'git clean -n && git clean -fdx'
  [ "$status" -eq 2 ]
}

@test "allows rm -i and dry-run clean in a chain" {
  run_cmd 'true && rm -i notas.md'
  [ "$status" -eq 0 ]
  run_cmd 'cd repo && git clean -n'
  [ "$status" -eq 0 ]
  run_cmd 'true && rm /tmp/opencode/x.log'
  [ "$status" -eq 0 ]
}

@test "allows mentions inside a commit message or an echo" {
  run_cmd 'git commit -m "no usar git stash ni rm -rf build"'
  [ "$status" -eq 0 ]
  run_cmd "echo 'rm -rf build'"
  [ "$status" -eq 0 ]
  run_cmd 'grep -n "git reset --hard" docs/x.md'
  [ "$status" -eq 0 ]
  run_cmd 'echo "usa \`rm -rf build\` con cuidado"'
  [ "$status" -eq 0 ]
}

@test "allows safe lookalikes: rmdir, git checkout of a file, git status chained" {
  run_cmd 'true && rmdir vacio'
  [ "$status" -eq 0 ]
  run_cmd 'cd repo && git checkout -- src/a.ts'
  [ "$status" -eq 0 ]
  run_cmd 'cd repo && git status'
  [ "$status" -eq 0 ]
}

@test "edge: empty input and missing command pass through" {
  run bash -c 'bash "$1" </dev/null' _ "$HOOK"
  [ "$status" -eq 0 ]
  run_cmd ''
  [ "$status" -eq 0 ]
}

@test "edge: commands with only whitespace before rm still block" {
  run_cmd '   rm -rf build'
  [ "$status" -eq 2 ]
}

@test "edge: large chain of harmless commands passes" {
  run_cmd 'cd repo && git status && git diff --stat && ls -la && echo listo; git log --oneline -5 | head -3'
  [ "$status" -eq 0 ]
}

@test "edge: zero-argument rm and null input do not crash the hook" {
  run_cmd 'true && rm'
  [ "$status" -eq 0 ]
  run bash -c 'bash "$1" <<<"null"' _ "$HOOK"
  [ "$status" -eq 0 ]
}

@test "allows git clean --dry-run and git -C status" {
  run_cmd 'git -C "mi repo" clean --dry-run'
  [ "$status" -eq 0 ]
  run_cmd 'git -C repo status'
  [ "$status" -eq 0 ]
}

@test "allows git reset without --hard after a separator" {
  run_cmd 'cd repo && git reset HEAD notas.md'
  [ "$status" -eq 0 ]
}
