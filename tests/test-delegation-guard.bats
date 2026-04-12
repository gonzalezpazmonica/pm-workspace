#!/usr/bin/env bats
# BATS tests for SE-031 Delegation Toolset Enforcement
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-031-delegation-toolset-enforcement.md
# SCRIPT: .claude/hooks/delegation-guard.sh
# Quality gate: SPEC-055 (audit score >=80)
# Safety: tests use BATS run/status guards; target script has set -uo pipefail
# Status: active
# Date: 2026-04-12
# Era: 231
# Problem: subagents can recursively spawn more agents without limits
# Solution: hook enforces max delegation depth of 1 and blocks recursive spawning
# Acceptance: depth 0 passes, depth 1+ blocks Agent, trace logged, non-Agent passes
# Dependencies: delegation-guard.sh

## Problem: no limit on recursive agent delegation — could cause delegation bombs
## Solution: hook tracks SAVIA_DELEGATION_DEPTH and blocks Agent tool at depth >= 1
## Acceptance: normal delegation allowed, recursive blocked, trace logged

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HOOK="$REPO_ROOT/.claude/hooks/delegation-guard.sh"
  TMPDIR_DEL=$(mktemp -d)
  export CLAUDE_PROJECT_DIR="$TMPDIR_DEL"
  mkdir -p "$TMPDIR_DEL/output"
}
teardown() {
  rm -rf "$TMPDIR_DEL"
}

_run_hook() {
  local json="$1"
  local depth="${2:-0}"
  SAVIA_DELEGATION_DEPTH="$depth" bash -c "echo '$json' | bash '$HOOK'" 2>&1
}

## Structural tests

@test "delegation-guard.sh exists and is executable" {
  [[ -x "$HOOK" ]]
  bash -n "$HOOK"
}
@test "uses set -uo pipefail" {
  head -3 "$HOOK" | grep -q "set -uo pipefail"
}
@test "spec exists" {
  [[ -f "$REPO_ROOT/docs/propuestas/savia-enterprise/SPEC-SE-031-delegation-toolset-enforcement.md" ]]
}

## Normal delegation (depth 0 → 1)

@test "allows Agent at depth 0 (normal delegation)" {
  local json='{"tool_name":"Agent","tool_input":{"prompt":"Implement feature X","subagent_type":"dotnet-developer","name":"dev"}}'
  run _run_hook "$json" 0
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"BLOCKED"* ]]
}

## Recursive delegation (BLOCK)

@test "blocks Agent at depth 1 (recursive delegation)" {
  local json='{"tool_name":"Agent","tool_input":{"prompt":"Do something","subagent_type":"general-purpose"}}'
  run _run_hook "$json" 1
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"BLOCKED"* ]]
  [[ "$output" == *"recursive"* ]]
}
@test "blocks Agent at depth 2" {
  local json='{"tool_name":"Agent","tool_input":{"prompt":"Deep nesting","subagent_type":"test-engineer"}}'
  run _run_hook "$json" 2
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"BLOCKED"* ]]
}

## Non-Agent tools pass

@test "allows non-Agent tools at any depth" {
  local json='{"tool_name":"Read","tool_input":{"file_path":"/tmp/test.md"}}'
  run _run_hook "$json" 1
  [[ "$status" -eq 0 ]]
}
@test "allows Bash at depth 1" {
  local json='{"tool_name":"Bash","tool_input":{"command":"echo hello"}}'
  run _run_hook "$json" 0
  [[ "$status" -eq 0 ]]
}

## Trace logging

@test "logs delegation trace on allowed invocations" {
  local json='{"tool_name":"Agent","tool_input":{"prompt":"Test task","subagent_type":"architect","name":"arch-1"}}'
  _run_hook "$json" 0 >/dev/null 2>&1
  [[ -f "$TMPDIR_DEL/output/delegation-trace/delegations.jsonl" ]]
  python3 -c "
import json
d = json.loads(open('$TMPDIR_DEL/output/delegation-trace/delegations.jsonl').readline())
assert d['agent_type'] == 'architect'
assert d['action'] == 'allowed'
assert d['depth'] == 0
"
}

## Edge cases

@test "empty stdin exits cleanly" {
  run bash "$HOOK"
  [[ "$status" -eq 0 ]]
}
@test "no SAVIA_DELEGATION_DEPTH defaults to 0 (allowed)" {
  local json='{"tool_name":"Agent","tool_input":{"prompt":"Normal","subagent_type":"test-engineer"}}'
  unset SAVIA_DELEGATION_DEPTH
  run bash -c "echo '$json' | bash '$HOOK'" 2>&1
  [[ "$status" -eq 0 ]]
}
