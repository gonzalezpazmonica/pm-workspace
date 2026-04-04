#!/usr/bin/env bats
# Tests for validate-agent-permissions.sh

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/validate-agent-permissions.sh"
  TMPDIR_AP=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_AP"
}

@test "runs on real agents directory" {
  run bash "$SCRIPT" "$REPO_ROOT/.claude/agents"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Agent Permission Validation"* ]]
  [[ "$output" == *"Checked:"* ]]
}

@test "reports checked count > 0" {
  run bash "$SCRIPT" "$REPO_ROOT/.claude/agents"
  checked=$(echo "$output" | grep "Checked:" | grep -oE '[0-9]+')
  [[ "$checked" -gt 0 ]]
}

@test "handles empty directory" {
  mkdir -p "$TMPDIR_AP/empty"
  run bash "$SCRIPT" "$TMPDIR_AP/empty"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Checked: 0"* ]]
}

@test "handles agent without permission_level" {
  mkdir -p "$TMPDIR_AP/agents"
  cat > "$TMPDIR_AP/agents/test-agent.md" << 'EOF'
---
name: test-agent
tools:
  - Read
---
Test agent without permission level.
EOF
  run bash "$SCRIPT" "$TMPDIR_AP/agents" --verbose
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"WARN"* ]]
}

@test "validates L0 agent correctly" {
  mkdir -p "$TMPDIR_AP/agents"
  cat > "$TMPDIR_AP/agents/observer.md" << 'EOF'
---
name: observer
permission_level: L0
tools:
  - Read
  - Glob
  - Grep
---
Observer agent.
EOF
  run bash "$SCRIPT" "$TMPDIR_AP/agents"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Errors:  0"* ]]
}

@test "detects unknown permission level" {
  mkdir -p "$TMPDIR_AP/agents"
  cat > "$TMPDIR_AP/agents/bad.md" << 'EOF'
---
name: bad-agent
permission_level: L9
tools:
  - Read
---
Bad level agent.
EOF
  run bash "$SCRIPT" "$TMPDIR_AP/agents"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" == *"unknown level"* ]]
}

@test "verbose flag shows warnings" {
  mkdir -p "$TMPDIR_AP/agents"
  cat > "$TMPDIR_AP/agents/missing.md" << 'EOF'
---
name: missing-level
tools:
  - Read
---
No level.
EOF
  run bash "$SCRIPT" "$TMPDIR_AP/agents" --verbose
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *"no permission_level"* ]]
}
