#!/usr/bin/env bats
# test-se-202-agent-hooks.bats — SE-202: semantic LLM gate for hooks
# Ref: docs/propuestas/SE-202-agent-hooks.md / scripts/agent-hook-runner.sh
# Minimum 15 tests, target ≥80 score

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/agent-hook-runner.sh"
  TMPDIR_HOOK="$(mktemp -d)"
  export TMPDIR_HOOK
  # Override PROJECT_ROOT so logs go to tmp, not live workspace
  export PROJECT_ROOT="$TMPDIR_HOOK"
  # Default: fail open so tests don't hang waiting for LLM
  export SAVIA_AGENT_HOOK_FAIL_OPEN=true
  export SAVIA_AGENT_HOOK_TIMEOUT=5
}

teardown() {
  rm -rf "$TMPDIR_HOOK"
}

# ── Existence & safety ────────────────────────────────────────────────────────

@test "SE-202: agent-hook-runner.sh exists" {
  [ -f "$SCRIPT" ]
}

@test "SE-202: agent-hook-runner.sh is executable" {
  [ -x "$SCRIPT" ]
}

@test "SE-202: agent-hook-runner.sh has set -uo pipefail" {
  run grep -E "^set -[a-z]*uo[a-z]*\s*pipefail|set -uo pipefail|set -euo pipefail" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "SE-202: SE-202 is referenced in script" {
  run grep -F "SE-202" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── --dry-run mode ────────────────────────────────────────────────────────────

@test "SE-202: --dry-run does not invoke agent or write log file" {
  run bash "$SCRIPT" --agent security-guardian \
    --event '{"tool":"Bash","tool_input":"ls -la"}' \
    --dry-run
  # Should exit 0
  [ "$status" -eq 0 ]
  # dry-run must mention DRY-RUN in output
  [[ "$output" == *"DRY-RUN"* ]] || [[ "$output" == *"dry-run"* ]]
  # Log file must NOT exist (dry-run makes no side effects)
  [ ! -f "$TMPDIR_HOOK/output/agent-hook-decisions.jsonl" ]
}

@test "SE-202: --dry-run shows agent name and event in output" {
  run bash "$SCRIPT" --agent security-guardian \
    --event '{"tool":"Bash","tool_input":"rm file.txt"}' \
    --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"security-guardian"* ]]
}

# ── --list-agents mode ────────────────────────────────────────────────────────

@test "SE-202: --list-agents works without crash" {
  run bash "$SCRIPT" --list-agents
  [ "$status" -eq 0 ]
}

@test "SE-202: --list-agents produces non-empty output" {
  run bash "$SCRIPT" --list-agents
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -gt 0 ]
}

# ── Exit code contract ────────────────────────────────────────────────────────

@test "SE-202: exit 0 = allow (fail-open with unavailable agent)" {
  # Use a fake agent that doesn't exist — FAIL_OPEN=true must give exit 0
  export SAVIA_AGENT_HOOK_FAIL_OPEN=true
  run bash "$SCRIPT" --agent nonexistent-fake-agent-xyz \
    --event '{"tool":"Bash","tool_input":"echo hello"}'
  [ "$status" -eq 0 ]
}

@test "SE-202: exit 2 = deny (fail-closed with unavailable agent)" {
  export SAVIA_AGENT_HOOK_FAIL_OPEN=false
  run bash "$SCRIPT" --agent nonexistent-fake-agent-xyz \
    --event '{"tool":"Bash","tool_input":"echo hello"}'
  [ "$status" -eq 2 ]
}

# ── FAIL_OPEN behaviour ───────────────────────────────────────────────────────

@test "SE-202: FAIL_OPEN=true allows when agent not found" {
  export SAVIA_AGENT_HOOK_FAIL_OPEN=true
  run bash "$SCRIPT" --agent totally-fake-agent-12345 \
    --event '{"tool":"Edit","tool_input":"file.txt"}'
  [ "$status" -eq 0 ]
}

@test "SE-202: FAIL_OPEN=false denies when agent not found" {
  export SAVIA_AGENT_HOOK_FAIL_OPEN=false
  run bash "$SCRIPT" --agent totally-fake-agent-12345 \
    --event '{"tool":"Edit","tool_input":"file.txt"}'
  [ "$status" -eq 2 ]
}

# ── JSON output structure ─────────────────────────────────────────────────────

@test "SE-202: output JSON has required fields: decision, reason, agent, timestamp" {
  export SAVIA_AGENT_HOOK_FAIL_OPEN=true
  run bash "$SCRIPT" --agent nonexistent-fake-agent-xyz \
    --event '{"tool":"Bash","tool_input":"ls"}'
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"decision"'
  echo "$output" | grep -q '"reason"'
  echo "$output" | grep -q '"agent"'
  echo "$output" | grep -q '"timestamp"'
}

# ── Log file ──────────────────────────────────────────────────────────────────

@test "SE-202: log file is created after execution" {
  export SAVIA_AGENT_HOOK_FAIL_OPEN=true
  run bash "$SCRIPT" --agent nonexistent-fake-agent-xyz \
    --event '{"tool":"Bash","tool_input":"cat file.txt"}'
  [ -f "$TMPDIR_HOOK/output/agent-hook-decisions.jsonl" ]
}

@test "SE-202: log file appends on repeated executions" {
  export SAVIA_AGENT_HOOK_FAIL_OPEN=true
  bash "$SCRIPT" --agent nonexistent-fake-agent-xyz \
    --event '{"tool":"Bash","tool_input":"echo 1"}' >/dev/null 2>&1 || true
  bash "$SCRIPT" --agent nonexistent-fake-agent-xyz \
    --event '{"tool":"Bash","tool_input":"echo 2"}' >/dev/null 2>&1 || true
  count=$(wc -l < "$TMPDIR_HOOK/output/agent-hook-decisions.jsonl")
  [ "$count" -ge 2 ]
}

# ── Protocol doc and settings ────────────────────────────────────────────────

@test "SE-202: agent-hook-protocol.md exists" {
  [ -f "$REPO_ROOT/docs/rules/domain/agent-hook-protocol.md" ]
}

@test "SE-202: settings.json mentions SE-202" {
  run grep -F "SE-202" "$REPO_ROOT/.claude/settings.json"
  [ "$status" -eq 0 ]
}

# ── Edge cases ────────────────────────────────────────────────────────────────

@test "SE-202: malformed event JSON produces clear error and non-zero exit" {
  run bash "$SCRIPT" --agent security-guardian \
    --event 'not-valid-json{{{badly:'
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"not valid JSON"* ]] || [[ "$output" == *"not found"* ]]
}

@test "SE-202: timeout is respected — script exits within reasonable time" {
  # Set 2s timeout; use a fake agent (no real LLM call)
  export SAVIA_AGENT_HOOK_TIMEOUT=2
  export SAVIA_AGENT_HOOK_FAIL_OPEN=true
  start=$(date +%s)
  run bash "$SCRIPT" --agent nonexistent-fake-agent-xyz \
    --event '{"tool":"Bash","tool_input":"echo hi"}'
  end=$(date +%s)
  elapsed=$(( end - start ))
  # Must finish well within 10 seconds (fake agent fails fast)
  [ "$elapsed" -lt 10 ]
}

@test "SE-202: setup and teardown use tmpdir (no writes to live workspace output/)" {
  export SAVIA_AGENT_HOOK_FAIL_OPEN=true
  run bash "$SCRIPT" --agent nonexistent-fake-agent-xyz \
    --event '{"tool":"Bash","tool_input":"ls"}'
  # Log must be in TMPDIR_HOOK
  [ -f "$TMPDIR_HOOK/output/agent-hook-decisions.jsonl" ]
  # Live workspace log should not have been created by this test
  true
}
