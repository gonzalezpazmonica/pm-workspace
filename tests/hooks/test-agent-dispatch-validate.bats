#!/usr/bin/env bats
# Tests for agent-dispatch-validate.sh hook
# Validates 5 dispatch contexts with required context checks

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK="$PWD/.claude/hooks/agent-dispatch-validate.sh"
  export CLAUDE_PROJECT_DIR="$PWD"
  export SAVIA_HOOK_PROFILE=strict
}

run_hook() {
  run bash -c "echo '$1' | bash '$HOOK'"
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
  run_hook '{"tool_name":"Task","tool_input":{"prompt":"Create a new file in .claude/commands/my-cmd.md with description field","subagent_type":"general-purpose"}}'
  [ "$status" -eq 2 ]
}

@test "command creation with name and description passes" {
  run_hook '{"tool_name":"Task","tool_input":{"prompt":"Create a new command in .claude/commands/my-cmd.md with frontmatter including name and description fields. Use existing command as example.","subagent_type":"general-purpose"}}'
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
  run_hook '{"tool_name":"Task","tool_input":{"prompt":"Create a new skill in .claude/skills/my-skill/SKILL.md","subagent_type":"general-purpose"}}'
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
