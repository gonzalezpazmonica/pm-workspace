#!/usr/bin/env bats
# tests/test-recursion-guard.bats — SPEC-RECURSION-GUARD
# Ref: docs/rules/domain/recursion-guard-protocol.md

HOOK="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/.opencode/hooks/recursion-guard.sh"
EXPORT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/recursion-guard-export.sh"

setup() {
  [[ -x "$HOOK" ]]   || skip "recursion-guard.sh missing or not executable"
  [[ -f "$EXPORT" ]] || skip "recursion-guard-export.sh missing"
  unset SAVIA_LOOP_CONTEXT
  unset OPENCODE_TOOL_INPUT
}

# Test 1: allows when SAVIA_LOOP_CONTEXT is unset

@test "allows tool call when SAVIA_LOOP_CONTEXT is unset" {
  export OPENCODE_TOOL_INPUT="overnight-sprint --sprint-id foo"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "allows tool call when SAVIA_LOOP_CONTEXT is empty string" {
  export SAVIA_LOOP_CONTEXT=""
  export OPENCODE_TOOL_INPUT="overnight-sprint --sprint-id foo"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

# Test 2: blocks overnight-sprint inside overnight-sprint

@test "blocks overnight-sprint when SAVIA_LOOP_CONTEXT=overnight-sprint:1" {
  export SAVIA_LOOP_CONTEXT="overnight-sprint:1"
  export OPENCODE_TOOL_INPUT='{"skill":"overnight-sprint","args":{}}'
  run bash "$HOOK"
  [ "$status" -eq 2 ]
}

# Test 3: blocks code-improvement-loop inside overnight-sprint

@test "blocks code-improvement-loop when inside overnight-sprint" {
  export SAVIA_LOOP_CONTEXT="overnight-sprint:1"
  export OPENCODE_TOOL_INPUT='run skill code-improvement-loop'
  run bash "$HOOK"
  [ "$status" -eq 2 ]
}

# Test 4: allows normal tool calls inside a loop

@test "allows bash tool call inside a loop" {
  export SAVIA_LOOP_CONTEXT="overnight-sprint:1"
  export OPENCODE_TOOL_INPUT='{"command":"bash","input":"ls -la"}'
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "allows git tool call inside a loop" {
  export SAVIA_LOOP_CONTEXT="overnight-sprint:2"
  export OPENCODE_TOOL_INPUT='{"command":"git","args":["status"]}'
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

# Test 5: verifies block message format

@test "block message contains BLOCKED [recursion-guard]" {
  export SAVIA_LOOP_CONTEXT="overnight-sprint:1"
  export OPENCODE_TOOL_INPUT="tech-research-agent topic=foo"
  run bash "$HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOCKED [recursion-guard]"* ]]
}

@test "block message includes current SAVIA_LOOP_CONTEXT value" {
  export SAVIA_LOOP_CONTEXT="overnight-sprint:3"
  export OPENCODE_TOOL_INPUT="loop_skill run"
  run bash "$HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"overnight-sprint:3"* ]]
}

# Test 6: exit code 2 on block

@test "exit code is exactly 2 when blocking" {
  export SAVIA_LOOP_CONTEXT="code-improvement-loop:1"
  export OPENCODE_TOOL_INPUT="code-improvement-loop --target src/"
  run bash "$HOOK"
  [ "$status" -eq 2 ]
}

# Test 7: recursion-guard-export.sh increments depth

@test "recursion-guard-export increments depth from 0 to 1" {
  unset SAVIA_LOOP_CONTEXT
  # shellcheck disable=SC1090
  source "$EXPORT" "overnight-sprint"
  [ "$SAVIA_LOOP_CONTEXT" = "overnight-sprint:1" ]
}

@test "recursion-guard-export increments depth from 1 to 2" {
  export SAVIA_LOOP_CONTEXT="overnight-sprint:1"
  # shellcheck disable=SC1090
  source "$EXPORT" "overnight-sprint"
  [ "$SAVIA_LOOP_CONTEXT" = "overnight-sprint:2" ]
}

# Test 8: depth cascade 0 -> 1 -> 2 -> 3

@test "depth cascades correctly across three source calls" {
  unset SAVIA_LOOP_CONTEXT
  # shellcheck disable=SC1090
  source "$EXPORT" "overnight-sprint"
  [ "$SAVIA_LOOP_CONTEXT" = "overnight-sprint:1" ]
  # shellcheck disable=SC1090
  source "$EXPORT" "overnight-sprint"
  [ "$SAVIA_LOOP_CONTEXT" = "overnight-sprint:2" ]
  # shellcheck disable=SC1090
  source "$EXPORT" "overnight-sprint"
  [ "$SAVIA_LOOP_CONTEXT" = "overnight-sprint:3" ]
}

# ── New cases (14 total) ──────────────────────────────────────────────────────

# Test 9: source with no argument → return 1, SAVIA_LOOP_CONTEXT not modified
@test "source export with no argument → return 1, SAVIA_LOOP_CONTEXT unchanged" {
  # Run source in a subshell to capture rc; outer SAVIA_LOOP_CONTEXT stays unset
  local result
  result=$(bash --norc -c "
    unset SAVIA_LOOP_CONTEXT
    # shellcheck disable=SC1090
    source \"$EXPORT\" 2>/dev/null
    rc=\$?
    echo \"rc=\${rc} ctx=\${SAVIA_LOOP_CONTEXT:-UNSET}\"
  " 2>/dev/null) || true
  # source returned non-zero (rc=1)
  echo "$result" | grep -q "rc=1"
  # SAVIA_LOOP_CONTEXT was not modified (remains UNSET in the subshell)
  echo "$result" | grep -q "ctx=UNSET"
}

# Test 10: without SAVIA_LOOP_CONTEXT, any OPENCODE_TOOL_INPUT → exit 0
@test "no SAVIA_LOOP_CONTEXT + any OPENCODE_TOOL_INPUT -> exit 0 (no context means no block)" {
  unset SAVIA_LOOP_CONTEXT
  export OPENCODE_TOOL_INPUT="overnight-sprint --sprint-id bar"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

# Test 11: cross-loop depth: overnight-sprint (depth 1) → code-improvement-loop (depth 2)
@test "cross-loop depth: overnight-sprint then code-improvement-loop → depth 2 with new name" {
  unset SAVIA_LOOP_CONTEXT
  # shellcheck disable=SC1090
  source "$EXPORT" "overnight-sprint"
  [ "$SAVIA_LOOP_CONTEXT" = "overnight-sprint:1" ]
  # shellcheck disable=SC1090
  source "$EXPORT" "code-improvement-loop"
  [ "$SAVIA_LOOP_CONTEXT" = "code-improvement-loop:2" ]
}

# Test 12: OPENCODE_TOOL_INPUT unset + SAVIA_LOOP_CONTEXT set → exit 0 (no input = no loop)
@test "OPENCODE_TOOL_INPUT unset + SAVIA_LOOP_CONTEXT set → exit 0 (no tool input to block)" {
  export SAVIA_LOOP_CONTEXT="overnight-sprint:1"
  unset OPENCODE_TOOL_INPUT
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}
