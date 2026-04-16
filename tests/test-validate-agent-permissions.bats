#!/usr/bin/env bats
# Ref: docs/rules/domain/agent-policies.md
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

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "edge: nonexistent directory returns zero checked" {
  run bash "$SCRIPT" "/nonexistent/path/xyz"
  [[ "$output" == *"Checked: 0"* ]] || [[ "$status" -ne 0 ]]
}

@test "edge: agent with special chars in name handled" {
  mkdir -p "$TMPDIR_AP/agents"
  echo -e "---\nname: bad\ntools: [Read]\n---\nTest." > "$TMPDIR_AP/agents/sp ecial.md"
  run bash "$SCRIPT" "$TMPDIR_AP/agents"
  [[ "$status" -le 1 ]]
}

@test "negative: L3 agent missing Write tool warns" {
  mkdir -p "$TMPDIR_AP/agents"
  cat > "$TMPDIR_AP/agents/dev.md" << 'EOF'
---
name: dev
permission_level: L3
tools:
  - Read
  - Glob
---
Dev with insufficient tools for L3.
EOF
  run bash "$SCRIPT" "$TMPDIR_AP/agents" --verbose
  [[ "$output" == *"WARN"* ]] || [[ "$output" == *"missing"* ]]
}

@test "negative: multiple agents with errors counted" {
  mkdir -p "$TMPDIR_AP/agents"
  echo -e "---\nname: a\npermission_level: L99\ntools: [Read]\n---\nBad." > "$TMPDIR_AP/agents/a.md"
  echo -e "---\nname: b\npermission_level: L99\ntools: [Read]\n---\nBad." > "$TMPDIR_AP/agents/b.md"
  run bash "$SCRIPT" "$TMPDIR_AP/agents"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Errors:  2"* ]]
}

@test "coverage: LEVEL_TOOLS array defined" {
  grep -q "LEVEL_TOOLS" "$SCRIPT"
}
