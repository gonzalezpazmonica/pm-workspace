#!/usr/bin/env bats
# tests/test-se-266-agent-git.bats — Tests for agent-git-discipline hook (SE-266)
# Extended: git destructive ops + shell safety layer (v2)

HOOK="${BATS_TEST_DIRNAME}/../.opencode/hooks/agent-git-discipline.sh"

setup() {
  [[ -x "$HOOK" ]] || skip "agent-git-discipline.sh not executable at $HOOK"
}

# Helper: pipe a JSON command directly to the hook (no bash -c, no export -f)
run_hook() {
  local cmd="$1"
  printf '{"tool_input":{"command":"%s"}}' "$cmd" | bash "$HOOK"
}

# ═══════════════════════════════════════════════════════════════════════
# Shell destructive operations (v2)
# ═══════════════════════════════════════════════════════════════════════

@test "SE266-T01: blocks rm -rf" {
  run run_hook "rm -rf /tmp/foo"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T02: blocks rm -r" {
  run run_hook "rm -r /tmp/bar"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T03: blocks rm -fr" {
  run run_hook "rm -fr /tmp/baz"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T04: blocks rm --recursive" {
  run run_hook "rm --recursive /tmp/qux"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T05: blocks rm without -i flag" {
  run run_hook "rm file.txt"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T06: blocks rm -f without -i flag" {
  run run_hook "rm -f file.txt"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T07: blocks sudo rm -rf" {
  run run_hook "sudo rm -rf /etc/foo"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T08: allows rm with -i" {
  run run_hook "rm -i file.txt"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T09: allows rm --interactive" {
  run run_hook "rm --interactive file.txt"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T10: allows rm in safe /tmp/opencode path" {
  run run_hook "rm /tmp/opencode/temp.txt"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T11: allows rm in safe /tmp/recovery path" {
  run run_hook "rm /tmp/recovery/test.txt"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T12: blocks dd writing to block device" {
  run run_hook "dd if=/dev/zero of=/dev/sda"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T13: blocks mkfs format" {
  run run_hook "mkfs.ext4 /dev/sdb"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T14: blocks sudo mkfs" {
  run run_hook "sudo mkfs.xfs /dev/sdc"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T15: blocks chown -R on home" {
  run run_hook "sudo chown -R user /home/monica"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T16: blocks truncate of home file" {
  run run_hook "cat /dev/null > /home/monica/.bashrc"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

# ═══════════════════════════════════════════════════════════════════════
# Git destructive operations (original SE-266)
# ═══════════════════════════════════════════════════════════════════════

@test "SE266-T17: blocks git reset --hard" {
  run run_hook "git reset --hard"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T18: blocks git clean -fd" {
  run run_hook "git clean -fd"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T19: blocks git stash" {
  run run_hook "git stash"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T20: blocks git checkout ." {
  run run_hook "git checkout ."
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T21: warns on git add -A" {
  run run_hook "git add -A"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "WARN" ]]
}

@test "SE266-T22: warns on git add ." {
  run run_hook "git add ."
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "WARN" ]]
}

@test "SE266-T23: allows explicit git add path" {
  run run_hook "git add src/main.sh"
  [[ "$status" -eq 0 ]]
  [[ ! "$output" =~ "BLOCKED" ]]
  [[ ! "$output" =~ "WARN" ]]
}

@test "SE266-T24: passes through non-git non-rm commands" {
  run run_hook "ls -la"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T25: allows git clean dry-run (-fdn)" {
  run run_hook "git clean -fdn"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T26: allows git clean with -n flag" {
  run run_hook "git clean -n"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T27: blocks git clean -f without dry-run" {
  run run_hook "git clean -f"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T28: passes through git status" {
  run run_hook "git status"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T29: passes through git diff" {
  run run_hook "git diff"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T30: passes through git log" {
  run run_hook "git log --oneline -5"
  [[ "$status" -eq 0 ]]
}
