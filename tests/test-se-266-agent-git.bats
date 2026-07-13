#!/usr/bin/env bats
# tests/test-se-266-agent-git.bats — Tests for agent-git-discipline hook (SE-266)
# Extended: git destructive ops + rm -rf + rm without confirmation + other shell hazards

HOOK="${BATS_TEST_DIRNAME}/../.opencode/hooks/agent-git-discipline.sh"

setup() {
  [[ -x "$HOOK" ]] || skip "agent-git-discipline.sh not executable at $HOOK"
}

json_cmd() {
  local cmd="$1"
  printf '{"tool_input":{"command":"%s"}}' "$cmd"
}

# ═══════════════════════════════════════════════════════════════════════
# rm operations (new — SE-266 extension)
# ═══════════════════════════════════════════════════════════════════════

@test "SE266-T01: blocks rm -rf" {
  run bash -c "json_cmd 'rm -rf /tmp/foo' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T02: blocks rm -r" {
  run bash -c "json_cmd 'rm -r /tmp/bar' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T03: blocks rm -fr (combined flags)" {
  run bash -c "json_cmd 'rm -fr /tmp/baz' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T04: blocks rm --recursive (but not --interactive)" {
  run bash -c "json_cmd 'rm --recursive /tmp/qux' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T05: blocks rm without -i flag" {
  run bash -c "json_cmd 'rm file.txt' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T06: blocks rm -f without -i flag" {
  run bash -c "json_cmd 'rm -f file.txt' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T07: blocks sudo rm -rf" {
  run bash -c "json_cmd 'sudo rm -rf /etc/foo' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T08: allows rm with -i (interactive)" {
  run bash -c "json_cmd 'rm -i file.txt' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T09: allows rm --interactive" {
  run bash -c "json_cmd 'rm --interactive file.txt' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T10: allows rm in safe /tmp/opencode path" {
  run bash -c "json_cmd 'rm /tmp/opencode/temp.txt' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T11: allows rm in safe /tmp/recovery path" {
  run bash -c "json_cmd 'rm /tmp/recovery/test.txt' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

# ═══════════════════════════════════════════════════════════════════════
# Other destructive shell operations (new)
# ═══════════════════════════════════════════════════════════════════════

@test "SE266-T12: blocks dd writing to block device" {
  run bash -c "json_cmd 'dd if=/dev/zero of=/dev/sda' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T13: blocks mkfs format operation" {
  run bash -c "json_cmd 'mkfs.ext4 /dev/sdb' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T14: blocks sudo mkfs" {
  run bash -c "json_cmd 'sudo mkfs.xfs /dev/sdc' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T15: blocks chown -R on home" {
  run bash -c "json_cmd 'sudo chown -R user /home/monica' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T16: blocks truncate of home file (> redirect)" {
  run bash -c "json_cmd \"cat /dev/null > /home/monica/.bashrc\" | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

# ═══════════════════════════════════════════════════════════════════════
# Git destructive operations (SE-266 original, Pi-inspired)
# ═══════════════════════════════════════════════════════════════════════

@test "SE266-T17: blocks destructive reset --hard" {
  run bash -c "json_cmd 'git reset --hard' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T18: blocks destructive clean -fd" {
  run bash -c "json_cmd 'git clean -fd' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T19: blocks stash operation" {
  run bash -c "json_cmd 'git stash' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T20: blocks checkout dot" {
  run bash -c "json_cmd 'git checkout .' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T21: warns on git add -A" {
  run bash -c "json_cmd 'git add -A' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "WARN" ]]
}

@test "SE266-T22: warns on git add ." {
  run bash -c "json_cmd 'git add .' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "WARN" ]]
}

@test "SE266-T23: allows explicit git add path" {
  run bash -c "json_cmd 'git add src/main.sh' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ ! "$output" =~ "BLOCKED" ]]
  [[ ! "$output" =~ "WARN" ]]
}

@test "SE266-T24: passes through non-git non-rm commands" {
  run bash -c "json_cmd 'ls -la' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T25: allows git clean dry-run (-fdn)" {
  run bash -c "json_cmd 'git clean -fdn' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T26: allows git clean with -n flag" {
  run bash -c "json_cmd 'git clean -n' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T27: blocks git clean -f without dry-run" {
  run bash -c "json_cmd 'git clean -f' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T28: passes through git status" {
  run bash -c "json_cmd 'git status' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T29: passes through git diff" {
  run bash -c "json_cmd 'git diff' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T30: passes through git log" {
  run bash -c "json_cmd 'git log --oneline -5' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}
