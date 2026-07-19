#!/usr/bin/env bats
# tests/test-se-266-agent-git.bats — Tests for agent-git-discipline hook (SE-266)
<<<<<<< HEAD
# Extended: git destructive ops + rm -rf + rm without confirmation + other shell hazards
=======
# Extended: git destructive ops + shell safety layer (v2)
>>>>>>> origin/main

HOOK="${BATS_TEST_DIRNAME}/../.opencode/hooks/agent-git-discipline.sh"

setup() {
  [[ -x "$HOOK" ]] || skip "agent-git-discipline.sh not executable at $HOOK"
}

<<<<<<< HEAD
json_cmd() {
  local cmd="$1"
  printf '{"tool_input":{"command":"%s"}}' "$cmd"
}

# ═══════════════════════════════════════════════════════════════════════
# rm operations (new — SE-266 extension)
# ═══════════════════════════════════════════════════════════════════════

@test "SE266-T01: blocks rm -rf" {
  run bash -c "json_cmd 'rm -rf /tmp/foo' | bash '$HOOK'"
=======
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
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T02: blocks rm -r" {
<<<<<<< HEAD
  run bash -c "json_cmd 'rm -r /tmp/bar' | bash '$HOOK'"
=======
  run run_hook "rm -r /tmp/bar"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

<<<<<<< HEAD
@test "SE266-T03: blocks rm -fr (combined flags)" {
  run bash -c "json_cmd 'rm -fr /tmp/baz' | bash '$HOOK'"
=======
@test "SE266-T03: blocks rm -fr" {
  run run_hook "rm -fr /tmp/baz"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

<<<<<<< HEAD
@test "SE266-T04: blocks rm --recursive (but not --interactive)" {
  run bash -c "json_cmd 'rm --recursive /tmp/qux' | bash '$HOOK'"
=======
@test "SE266-T04: blocks rm --recursive" {
  run run_hook "rm --recursive /tmp/qux"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T05: blocks rm without -i flag" {
<<<<<<< HEAD
  run bash -c "json_cmd 'rm file.txt' | bash '$HOOK'"
=======
  run run_hook "rm file.txt"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T06: blocks rm -f without -i flag" {
<<<<<<< HEAD
  run bash -c "json_cmd 'rm -f file.txt' | bash '$HOOK'"
=======
  run run_hook "rm -f file.txt"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T07: blocks sudo rm -rf" {
<<<<<<< HEAD
  run bash -c "json_cmd 'sudo rm -rf /etc/foo' | bash '$HOOK'"
=======
  run run_hook "sudo rm -rf /etc/foo"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

<<<<<<< HEAD
@test "SE266-T08: allows rm with -i (interactive)" {
  run bash -c "json_cmd 'rm -i file.txt' | bash '$HOOK'"
=======
@test "SE266-T08: allows rm with -i" {
  run run_hook "rm -i file.txt"
>>>>>>> origin/main
  [[ "$status" -eq 0 ]]
}

@test "SE266-T09: allows rm --interactive" {
<<<<<<< HEAD
  run bash -c "json_cmd 'rm --interactive file.txt' | bash '$HOOK'"
=======
  run run_hook "rm --interactive file.txt"
>>>>>>> origin/main
  [[ "$status" -eq 0 ]]
}

@test "SE266-T10: allows rm in safe /tmp/opencode path" {
<<<<<<< HEAD
  run bash -c "json_cmd 'rm /tmp/opencode/temp.txt' | bash '$HOOK'"
=======
  run run_hook "rm /tmp/opencode/temp.txt"
>>>>>>> origin/main
  [[ "$status" -eq 0 ]]
}

@test "SE266-T11: allows rm in safe /tmp/recovery path" {
<<<<<<< HEAD
  run bash -c "json_cmd 'rm /tmp/recovery/test.txt' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

# ═══════════════════════════════════════════════════════════════════════
# Other destructive shell operations (new)
# ═══════════════════════════════════════════════════════════════════════

@test "SE266-T12: blocks dd writing to block device" {
  run bash -c "json_cmd 'dd if=/dev/zero of=/dev/sda' | bash '$HOOK'"
=======
  run run_hook "rm /tmp/recovery/test.txt"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T12: blocks dd writing to block device" {
  run run_hook "dd if=/dev/zero of=/dev/sda"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

<<<<<<< HEAD
@test "SE266-T13: blocks mkfs format operation" {
  run bash -c "json_cmd 'mkfs.ext4 /dev/sdb' | bash '$HOOK'"
=======
@test "SE266-T13: blocks mkfs format" {
  run run_hook "mkfs.ext4 /dev/sdb"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T14: blocks sudo mkfs" {
<<<<<<< HEAD
  run bash -c "json_cmd 'sudo mkfs.xfs /dev/sdc' | bash '$HOOK'"
=======
  run run_hook "sudo mkfs.xfs /dev/sdc"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T15: blocks chown -R on home" {
<<<<<<< HEAD
  run bash -c "json_cmd 'sudo chown -R user /home/monica' | bash '$HOOK'"
=======
  run run_hook "sudo chown -R user /home/monica"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

<<<<<<< HEAD
@test "SE266-T16: blocks truncate of home file (> redirect)" {
  run bash -c "json_cmd \"cat /dev/null > /home/monica/.bashrc\" | bash '$HOOK'"
=======
@test "SE266-T16: blocks truncate of home file" {
  run run_hook "cat /dev/null > /home/monica/.bashrc"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

# ═══════════════════════════════════════════════════════════════════════
<<<<<<< HEAD
# Git destructive operations (SE-266 original, Pi-inspired)
# ═══════════════════════════════════════════════════════════════════════

@test "SE266-T17: blocks destructive reset --hard" {
  run bash -c "json_cmd 'git reset --hard' | bash '$HOOK'"
=======
# Git destructive operations (original SE-266)
# ═══════════════════════════════════════════════════════════════════════

@test "SE266-T17: blocks git reset --hard" {
  run run_hook "git reset --hard"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

<<<<<<< HEAD
@test "SE266-T18: blocks destructive clean -fd" {
  run bash -c "json_cmd 'git clean -fd' | bash '$HOOK'"
=======
@test "SE266-T18: blocks git clean -fd" {
  run run_hook "git clean -fd"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

<<<<<<< HEAD
@test "SE266-T19: blocks stash operation" {
  run bash -c "json_cmd 'git stash' | bash '$HOOK'"
=======
@test "SE266-T19: blocks git stash" {
  run run_hook "git stash"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

<<<<<<< HEAD
@test "SE266-T20: blocks checkout dot" {
  run bash -c "json_cmd 'git checkout .' | bash '$HOOK'"
=======
@test "SE266-T20: blocks git checkout ." {
  run run_hook "git checkout ."
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T21: warns on git add -A" {
<<<<<<< HEAD
  run bash -c "json_cmd 'git add -A' | bash '$HOOK'"
=======
  run run_hook "git add -A"
>>>>>>> origin/main
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "WARN" ]]
}

@test "SE266-T22: warns on git add ." {
<<<<<<< HEAD
  run bash -c "json_cmd 'git add .' | bash '$HOOK'"
=======
  run run_hook "git add ."
>>>>>>> origin/main
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "WARN" ]]
}

@test "SE266-T23: allows explicit git add path" {
<<<<<<< HEAD
  run bash -c "json_cmd 'git add src/main.sh' | bash '$HOOK'"
=======
  run run_hook "git add src/main.sh"
>>>>>>> origin/main
  [[ "$status" -eq 0 ]]
  [[ ! "$output" =~ "BLOCKED" ]]
  [[ ! "$output" =~ "WARN" ]]
}

@test "SE266-T24: passes through non-git non-rm commands" {
<<<<<<< HEAD
  run bash -c "json_cmd 'ls -la' | bash '$HOOK'"
=======
  run run_hook "ls -la"
>>>>>>> origin/main
  [[ "$status" -eq 0 ]]
}

@test "SE266-T25: allows git clean dry-run (-fdn)" {
<<<<<<< HEAD
  run bash -c "json_cmd 'git clean -fdn' | bash '$HOOK'"
=======
  run run_hook "git clean -fdn"
>>>>>>> origin/main
  [[ "$status" -eq 0 ]]
}

@test "SE266-T26: allows git clean with -n flag" {
<<<<<<< HEAD
  run bash -c "json_cmd 'git clean -n' | bash '$HOOK'"
=======
  run run_hook "git clean -n"
>>>>>>> origin/main
  [[ "$status" -eq 0 ]]
}

@test "SE266-T27: blocks git clean -f without dry-run" {
<<<<<<< HEAD
  run bash -c "json_cmd 'git clean -f' | bash '$HOOK'"
=======
  run run_hook "git clean -f"
>>>>>>> origin/main
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T28: passes through git status" {
<<<<<<< HEAD
  run bash -c "json_cmd 'git status' | bash '$HOOK'"
=======
  run run_hook "git status"
>>>>>>> origin/main
  [[ "$status" -eq 0 ]]
}

@test "SE266-T29: passes through git diff" {
<<<<<<< HEAD
  run bash -c "json_cmd 'git diff' | bash '$HOOK'"
=======
  run run_hook "git diff"
>>>>>>> origin/main
  [[ "$status" -eq 0 ]]
}

@test "SE266-T30: passes through git log" {
<<<<<<< HEAD
  run bash -c "json_cmd 'git log --oneline -5' | bash '$HOOK'"
=======
  run run_hook "git log --oneline -5"
>>>>>>> origin/main
  [[ "$status" -eq 0 ]]
}
