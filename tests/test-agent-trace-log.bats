#!/usr/bin/env bats
# BATS tests for .claude/hooks/agent-trace-log.sh
# PostToolUse — logs Task (subagent) executions + token budget metering.
# SPEC-AGENT-METERING.
# Ref: batch 44 hook coverage

HOOK=".claude/hooks/agent-trace-log.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export CLAUDE_PROJECT_DIR="$TMPDIR/ws-$$"
  export CLAUDE_PROJECT_NAME="testproj"
  mkdir -p "$CLAUDE_PROJECT_DIR/projects/testproj/traces"
  mkdir -p "$CLAUDE_PROJECT_DIR/scripts"
  # Mock agent-budget-lookup.sh (returns 1000 for any agent)
  cat > "$CLAUDE_PROJECT_DIR/scripts/agent-budget-lookup.sh" <<'EOF'
#!/bin/bash
echo "1000"
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/agent-budget-lookup.sh"
  # Pre-set required env vars (hook assumes they exist)
  export TOOL_NAME=""
  export TOOL_INPUT=""
  export TOOL_OUTPUT=""
  export TOOL_DURATION=0
  export TOOL_RESULT_STATUS=""
}
teardown() {
  rm -rf "$CLAUDE_PROJECT_DIR" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Skip paths ──────────────────────────────────────────

@test "skip: non-Task tool exits 0" {
  export TOOL_NAME=Edit
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [[ ! -f "$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl" ]]
}

@test "skip: Bash tool not traced" {
  export TOOL_NAME=Bash
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

# ── Task tool traces ────────────────────────────────────

@test "trace: Task invocation writes JSONL line" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"dotnet-developer","prompt":"implement feature"}'
  export TOOL_OUTPUT="Feature implemented successfully"
  export TOOL_DURATION=5
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  [[ -f "$log" ]]
  grep -q 'dotnet-developer' "$log"
}

@test "trace: unknown agent when agent field absent" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"prompt":"task without agent"}'
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -q '"agent":"unknown"' "$log"
}

@test "trace: token estimation ~= length/4" {
  export TOOL_NAME=Task
  # 400 chars input, 200 chars output → tokens_in=100, tokens_out=50
  export TOOL_INPUT=$(printf 'x%.0s' {1..400})
  export TOOL_OUTPUT=$(printf 'y%.0s' {1..200})
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -q '"tokens_in":100' "$log"
  grep -q '"tokens_out":50' "$log"
}

@test "trace: duration converted from seconds to ms" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'
  export TOOL_DURATION=3
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -q '"duration_ms":3000' "$log"
}

# ── Outcome classification ──────────────────────────────

@test "outcome: default success" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -q '"outcome":"success"' "$log"
}

@test "outcome: TOOL_RESULT_STATUS=error maps to failure" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'
  export TOOL_RESULT_STATUS=error
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -q '"outcome":"failure"' "$log"
}

@test "outcome: duration >120s maps to failure (timeout)" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'
  export TOOL_DURATION=150
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -q '"outcome":"failure"' "$log"
}

@test "outcome: TOOL_RESULT_STATUS=partial maps to partial" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'
  export TOOL_RESULT_STATUS=partial
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -q '"outcome":"partial"' "$log"
}

# ── Token budget metering ───────────────────────────────

@test "budget: lookup script called with agent name" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"expensive-agent"}'
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -q '"token_budget":1000' "$log"
}

@test "budget: exceeded=false when tokens <= budget" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'  # ~6 tokens
  export TOOL_OUTPUT="short output"
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -q '"budget_exceeded":false' "$log"
}

@test "budget: exceeded=true when tokens > budget + alert written" {
  # Make budget very small
  cat > "$CLAUDE_PROJECT_DIR/scripts/agent-budget-lookup.sh" <<'EOF'
#!/bin/bash
echo "10"
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/agent-budget-lookup.sh"
  export TOOL_NAME=Task
  export TOOL_INPUT=$(printf 'x%.0s' {1..400})  # 100 tokens
  export TOOL_OUTPUT="output"
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -q '"budget_exceeded":true' "$log"
  # Alert file should exist
  [[ -f "$CLAUDE_PROJECT_DIR/projects/testproj/traces/budget-alerts.jsonl" ]]
}

@test "budget: overage_pct calculated in alert" {
  cat > "$CLAUDE_PROJECT_DIR/scripts/agent-budget-lookup.sh" <<'EOF'
#!/bin/bash
echo "50"
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/agent-budget-lookup.sh"
  export TOOL_NAME=Task
  export TOOL_INPUT=$(printf 'x%.0s' {1..400})  # 100 tokens
  run bash "$HOOK"
  local alert="$CLAUDE_PROJECT_DIR/projects/testproj/traces/budget-alerts.jsonl"
  [[ -f "$alert" ]]
  grep -q '"overage"' "$alert"
  grep -q '"overage_pct"' "$alert"
}

@test "budget: missing lookup script defaults to 0 budget" {
  rm "$CLAUDE_PROJECT_DIR/scripts/agent-budget-lookup.sh"
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -q '"token_budget":0' "$log"
  # 0 budget means exceeded always false
  grep -q '"budget_exceeded":false' "$log"
}

# ── Trace format invariants ─────────────────────────────

@test "format: trace line has all required fields" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  for field in timestamp agent command tokens_in tokens_out token_budget budget_exceeded duration_ms files_modified outcome scope_violations; do
    grep -q "\"$field\"" "$log" || fail "missing field: $field"
  done
}

@test "format: timestamp is ISO 8601 UTC" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -qE '"timestamp":"20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' "$log"
}

@test "format: multiple calls append to same file" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'
  bash "$HOOK"
  bash "$HOOK"
  bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  local lines
  lines=$(wc -l < "$log")
  [[ "$lines" -eq 3 ]]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: empty TOOL_INPUT handled (length 0)" {
  export TOOL_NAME=Task
  export TOOL_INPUT=""
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "edge: empty TOOL_OUTPUT produces tokens_out=0" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'
  export TOOL_OUTPUT=""
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -q '"tokens_out":0' "$log"
}

@test "edge: duration 0 produces duration_ms=0" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'
  export TOOL_DURATION=0
  run bash "$HOOK"
  local log="$CLAUDE_PROJECT_DIR/projects/testproj/traces/agent-traces.jsonl"
  grep -q '"duration_ms":0' "$log"
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: SPEC-AGENT-METERING reference" {
  run grep -c 'SPEC-AGENT-METERING' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: 3 outcome categories (success, failure, partial)" {
  for outcome in success failure partial; do
    grep -q "\"$outcome\"" "$HOOK" || fail "missing outcome: $outcome"
  done
}

@test "coverage: token estimation divisor 4 (length/4)" {
  run grep -cE 'LENGTH / 4' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "coverage: budget-alerts file written when exceeded" {
  run grep -c 'budget-alerts.jsonl' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ────────────────────────────────────────────

@test "isolation: exit always 0 (PostToolUse never blocks)" {
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  export TOOL_NAME=Edit
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "isolation: traces dir auto-created if missing" {
  rm -rf "$CLAUDE_PROJECT_DIR/projects/testproj/traces"
  export TOOL_NAME=Task
  export TOOL_INPUT='{"agent":"a"}'
  run bash "$HOOK"
  [[ -d "$CLAUDE_PROJECT_DIR/projects/testproj/traces" ]]
}
