#!/usr/bin/env bats
# tests/test-se-266-agent-git.bats — Tests for agent-git-discipline hook (SE-266)

HOOK="${BATS_TEST_DIRNAME}/../.opencode/hooks/agent-git-discipline.sh"

setup() {
  [[ -x "$HOOK" ]] || skip "agent-git-discipline.sh not executable at $HOOK"
  export -f json_cmd 2>/dev/null || true
}

json_cmd() {
  local cmd="$1"
  printf '{"tool_input":{"command":"%s"}}' "$cmd"
}

@test "SE266-T01: blocks destructive reset --hard" {
  run bash -c "json_cmd 'git reset --hard' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T02: blocks destructive clean -fd" {
  run bash -c "json_cmd 'git clean -fd' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T03: blocks stash operation" {
  run bash -c "json_cmd 'git stash' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T04: blocks checkout dot" {
  run bash -c "json_cmd 'git checkout .' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T05: warns on git add -A" {
  run bash -c "json_cmd 'git add -A' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "WARN" ]]
}

@test "SE266-T06: warns on git add ." {
  run bash -c "json_cmd 'git add .' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "WARN" ]]
}

@test "SE266-T07: allows explicit git add path" {
  run bash -c "json_cmd 'git add src/main.sh' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ ! "$output" =~ "BLOCKED" ]]
  [[ ! "$output" =~ "WARN" ]]
}

@test "SE266-T08: passes through non-git commands" {
  run bash -c "json_cmd 'ls -la' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "SE266-T09: AGENTS.md has Git Discipline section" {
  grep -q "Git Discipline for Concurrent Agents" docs/AGENTS.md
}

@test "SE266-T10: AGENTS.md prohibits global stage" {
  grep -q "NEVER.*git add -A" docs/AGENTS.md || \
  grep -q "git add.*explicit" docs/AGENTS.md
}
