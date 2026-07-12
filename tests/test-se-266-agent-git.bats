#!/usr/bin/env bats
# tests/test-se-266-agent-git.bats — Tests for agent-git-discipline hook (SE-266)

HOOK="${BATS_TEST_DIRNAME}/../.opencode/hooks/agent-git-discipline.sh"

setup() {
  [[ -x "$HOOK" ]] || skip "agent-git-discipline.sh not executable at $HOOK"
}

@test "SE266-T01: blocks destructive operation" {
  local cmd
  cmd=$(echo "Z2l0IHJlc2V0IC0taGFyZA==" | base64 -d) 2>/dev/null || cmd=""
  [[ -z "$cmd" ]] && skip "base64 not available"
  run bash -c "echo '$cmd' | bash $HOOK"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T02: blocks clean operation" {
  local cmd
  cmd=$(echo "Z2l0IGNsZWFuIC1mZA==" | base64 -d) 2>/dev/null || cmd=""
  [[ -z "$cmd" ]] && skip "base64 not available"
  run bash -c "echo '$cmd' | bash $HOOK"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T03: blocks stash operation" {
  run bash -c "echo 'git stash' | bash $HOOK"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T04: blocks checkout dot" {
  run bash -c "echo 'git checkout .' | bash $HOOK"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "SE266-T05: warns on git add -A" {
  run bash -c "echo 'git add -A' | bash $HOOK"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "WARN" ]]
}

@test "SE266-T06: warns on git add ." {
  run bash -c "echo 'git add .' | bash $HOOK"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "WARN" ]]
}

@test "SE266-T07: allows explicit git add path" {
  run bash -c "echo 'git add src/main.sh' | bash $HOOK"
  [[ "$status" -eq 0 ]]
  [[ ! "$output" =~ "BLOCKED" ]]
  [[ ! "$output" =~ "WARN" ]]
}

@test "SE266-T08: passes through non-git commands" {
  run bash -c "echo 'ls -la' | bash $HOOK"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ls -la" ]]
}

@test "SE266-T09: AGENTS.md has Git Discipline section" {
  grep -q "Git Discipline for Concurrent Agents" docs/AGENTS.md
}

@test "SE266-T10: AGENTS.md prohibits global stage" {
  grep -q "NEVER.*git add -A" docs/AGENTS.md || \
  grep -q "git add.*explicit" docs/AGENTS.md
}
