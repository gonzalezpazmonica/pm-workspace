#!/usr/bin/env bats
# BATS tests for SPEC-161 PROTECTED_JOB_NAMES
# SPEC: docs/propuestas/SPEC-161-protected-job-names.md
# SCRIPT: .opencode/hooks/protected-job-guard.sh
# Quality gate: test-architect score >=80
# Safety: BATS run/status guards; target has set -uo pipefail
# Status: active
# Date: 2026-05-31
# Era: 251
# Problem: autonomous loops can invoke costly agents without gate, burning tokens
# Solution: PreToolUse hook on Task tool reads allowlist YAML and blocks protected agents in autonomous context
# Acceptance: AC-1 block in autonomous, AC-2 pass interactive, AC-3 override env, AC-4 missing YAML fail-safe
# Dependencies: protected-job-guard.sh, .opencode/protected-jobs.yaml

## Problem: heavy agents (architect, sdd-spec-writer) in overnight loops cost 80-120k tokens unguarded
## Solution: hook reads protected-jobs.yaml and exits 2 if subagent_type ∈ protected_agents AND autonomous context detected
## Acceptance: 6 ACs covered by tests below

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HOOK="$REPO_ROOT/.opencode/hooks/protected-job-guard.sh"
  TMPDIR_PJG=$(mktemp -d)
  export CLAUDE_PROJECT_DIR="$TMPDIR_PJG"
  mkdir -p "$TMPDIR_PJG/.opencode" "$TMPDIR_PJG/output"
  # Copy real YAML for default test fixture
  cp "$REPO_ROOT/.opencode/protected-jobs.yaml" "$TMPDIR_PJG/.opencode/protected-jobs.yaml"
  # Reset env vars
  unset SAVIA_AUTONOMOUS_MODE SAVIA_AUTONOMOUS_SKILL SAVIA_DELEGATION_DEPTH SAVIA_PROTECTED_JOB_OVERRIDE
}
teardown() {
  rm -rf "$TMPDIR_PJG"
}

_task_input() {
  local agent="$1"
  printf '{"tool_name":"Task","tool_input":{"subagent_type":"%s","prompt":"test"}}' "$agent"
}

## Structural tests

@test "hook exists and is executable" {
  [[ -x "$HOOK" ]]
  bash -n "$HOOK"
}

@test "uses set -uo pipefail" {
  head -10 "$HOOK" | grep -q "set -uo pipefail"
}

@test "spec exists" {
  [[ -f "$REPO_ROOT/docs/propuestas/SPEC-161-protected-job-names.md" ]]
}

@test "yaml exists with protected_agents and override_env" {
  [[ -r "$REPO_ROOT/.opencode/protected-jobs.yaml" ]]
  grep -q "^protected_agents:" "$REPO_ROOT/.opencode/protected-jobs.yaml"
  grep -q "^override_env:" "$REPO_ROOT/.opencode/protected-jobs.yaml"
}

## AC-1: blocks protected agent in autonomous context

@test "AC-1: blocks architect when SAVIA_AUTONOMOUS_MODE=1" {
  export SAVIA_AUTONOMOUS_MODE=1
  run bash -c "$(printf 'echo %q | bash %q' "$(_task_input architect)" "$HOOK")"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOCKED"* ]]
  [[ "$output" == *"architect"* ]]
}

@test "AC-1: blocks sdd-spec-writer when SAVIA_AUTONOMOUS_SKILL set" {
  export SAVIA_AUTONOMOUS_SKILL=overnight-sprint
  run bash -c "$(printf 'echo %q | bash %q' "$(_task_input sdd-spec-writer)" "$HOOK")"
  [[ "$status" -eq 2 ]]
}

@test "AC-1: blocks pentester at delegation depth 1" {
  export SAVIA_DELEGATION_DEPTH=1
  run bash -c "$(printf 'echo %q | bash %q' "$(_task_input pentester)" "$HOOK")"
  [[ "$status" -eq 2 ]]
}

## AC-2: permits in interactive context (no autonomous flags)

@test "AC-2: permits architect in interactive context (no env flags)" {
  run bash -c "$(printf 'echo %q | bash %q' "$(_task_input architect)" "$HOOK")"
  [[ "$status" -eq 0 ]]
}

@test "AC-2: permits non-protected agent (explore) in autonomous context" {
  export SAVIA_AUTONOMOUS_MODE=1
  run bash -c "$(printf 'echo %q | bash %q' "$(_task_input explore)" "$HOOK")"
  [[ "$status" -eq 0 ]]
}

## AC-3: override env permits protected agent

@test "AC-3: override env permits architect in autonomous mode" {
  export SAVIA_AUTONOMOUS_MODE=1
  export SAVIA_PROTECTED_JOB_OVERRIDE="@test-handle"
  run bash -c "$(printf 'echo %q | bash %q' "$(_task_input architect)" "$HOOK")"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"OVERRIDE"* ]]
}

## AC-4: fail-safe when YAML missing

@test "AC-4: YAML missing → exit 0 with WARN (fail-safe permissive)" {
  rm -f "$TMPDIR_PJG/.opencode/protected-jobs.yaml"
  export SAVIA_AUTONOMOUS_MODE=1
  run bash -c "$(printf 'echo %q | bash %q' "$(_task_input architect)" "$HOOK")"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"WARN"* ]]
}

## Edge cases

@test "non-Task tool invocation passes through" {
  export SAVIA_AUTONOMOUS_MODE=1
  local input='{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  run bash -c "$(printf 'echo %q | bash %q' "$input" "$HOOK")"
  [[ "$status" -eq 0 ]]
}

@test "Task without subagent_type passes through" {
  export SAVIA_AUTONOMOUS_MODE=1
  local input='{"tool_name":"Task","tool_input":{"prompt":"test"}}'
  run bash -c "$(printf 'echo %q | bash %q' "$input" "$HOOK")"
  [[ "$status" -eq 0 ]]
}

@test "empty stdin exits cleanly" {
  run bash -c "echo '' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "blocks all 12 declared protected agents in autonomous mode" {
  export SAVIA_AUTONOMOUS_MODE=1
  local agents=(architect sdd-spec-writer court-orchestrator truth-tribunal-orchestrator infrastructure-agent security-guardian drift-auditor pentester legal-compliance confidentiality-auditor meeting-risk-analyst model-upgrade-auditor)
  for a in "${agents[@]}"; do
    run bash -c "$(printf 'echo %q | bash %q' "$(_task_input "$a")" "$HOOK")"
    [[ "$status" -eq 2 ]] || { echo "FAIL: $a not blocked"; return 1; }
  done
}
