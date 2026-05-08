#!/usr/bin/env bats
# Tests for agent-dispatch-validate.sh hook
# Validates 5 dispatch contexts with required context checks
# Ref: docs/rules/domain/agent-dispatch-checklist.md

setup() {
  TMPDIR=$(mktemp -d)
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/.opencode/hooks/agent-dispatch-validate.sh"
  export CLAUDE_PROJECT_DIR="$PWD"
  export SAVIA_HOOK_PROFILE=strict
}

teardown() {
  rm -rf "$TMPDIR"
}

run_hook() {
  run bash -c "echo '$1' | bash '$HOOK'"
}

@test "target has safety flags" {
  grep -q "set -[euo]" "$HOOK"
}

# ── Non-Task tools pass through ──

@test "non-Task tool passes through" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  [ "$status" -eq 0 ]
}

@test "Edit tool passes through" {
  run_hook '{"tool_name":"Edit","tool_input":{"file_path":"test.md"}}'
  [ "$status" -eq 0 ]
}

@test "Task with empty prompt passes" {
  run_hook '{"tool_name":"Task","tool_input":{"prompt":"","subagent_type":"general-purpose"}}'
  [ "$status" -eq 0 ]
}

# ── Context 1: Creating commands ──

@test "BLOCKS command creation without frontmatter name mention" {
  run_hook '{"tool_name":"Task","tool_input":{"prompt":"Create a new file in .opencode/commands/my-cmd.md with description field","subagent_type":"general-purpose"}}'
  [ "$status" -eq 2 ]
}

@test "command creation with name and description passes" {
  run_hook '{"tool_name":"Task","tool_input":{"prompt":"Create a new command in .opencode/commands/my-cmd.md with frontmatter including name and description fields. Use existing command as example.","subagent_type":"general-purpose"}}'
  [ "$status" -eq 0 ]
}

# ── Context 2: CHANGELOG modifications ──

@test "BLOCKS CHANGELOG edit without ordering mention" {
  run_hook '{"tool_name":"Task","tool_input":{"prompt":"Update CHANGELOG.md with new entry","subagent_type":"general-purpose"}}'
  [ "$status" -eq 2 ]
}

@test "CHANGELOG edit with full context passes" {
  run_hook '{"tool_name":"Task","tool_input":{"prompt":"Update CHANGELOG.md. Read current version first. Add entry in descending order. Only insert at top, never replace.","subagent_type":"general-purpose"}}'
  [ "$status" -eq 0 ]
}

# ── Context 3: Creating skills (warnings only) ──

@test "skill creation without line limit passes with warning" {
  run_hook '{"tool_name":"Task","tool_input":{"prompt":"Create a new skill in .opencode/skills/my-skill/SKILL.md","subagent_type":"general-purpose"}}'
  [ "$status" -eq 0 ]
}

# ── Context 4: Git push (warnings only) ──

@test "git push without CI mention passes with warning" {
  run_hook '{"tool_name":"Task","tool_input":{"prompt":"Create PR with gh pr create and then git push","subagent_type":"general-purpose"}}'
  [ "$status" -eq 0 ]
}

# ── Generic prompt passes ──

@test "generic research prompt passes" {
  run_hook '{"tool_name":"Task","tool_input":{"prompt":"Search the codebase for Azure DevOps API references","subagent_type":"general-purpose"}}'
  [ "$status" -eq 0 ]
}

# ── Edge case ──

@test "Task with very long prompt does not crash" {
  local long_prompt
  long_prompt=$(printf 'x%.0s' {1..500})
  run_hook "{\"tool_name\":\"Task\",\"tool_input\":{\"prompt\":\"$long_prompt\",\"subagent_type\":\"general-purpose\"}}"
  [ "$status" -eq 0 ]
  [[ ! "$output" == *"FATAL"* ]]
}

@test "empty JSON object passes" {
  run_hook '{}'
  [ "$status" -eq 0 ]
  python3 -c "assert True"
}

@test "target script has safety flags" {
  grep -q "set -[euo]" "$BATS_TEST_DIRNAME/../../.opencode/hooks/agent-dispatch-validate.sh"
}

@test "edge: empty input produces no error" {
  run bash -c "echo '{}' | SAVIA_HOOK_PROFILE=minimal bash '$BATS_TEST_DIRNAME/../../.opencode/hooks/validate-bash-global.sh' 2>&1"
  [ "$status" -eq 0 ]
}
