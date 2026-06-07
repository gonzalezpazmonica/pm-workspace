#!/usr/bin/env bats
# tests/test-se-206-agent-idle.bats — SE-206: Agent Idle Detection
# Ref: docs/rules/domain/agent-idle-protocol.md

SCRIPT="$BATS_TEST_DIRNAME/../scripts/agent-wait-idle.sh"

setup() {
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── AC1: script exists and is executable ──────────────────────────────────────

@test "AC1a: script exists at expected path" {
  [ -f "$SCRIPT" ]
}

@test "AC1b: script is executable" {
  [ -x "$SCRIPT" ]
}

# ── AC2: hardening ────────────────────────────────────────────────────────────

@test "AC2a: script has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "AC2b: SE-206 is referenced in the script header" {
  grep -q 'SE-206' "$SCRIPT"
}

# ── AC3: --help ───────────────────────────────────────────────────────────────

@test "AC3: --help prints usage without error" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--pid"* ]]
  [[ "$output" == *"--timeout"* ]]
  [[ "$output" == *"--idle-threshold"* ]]
}

# ── AC4: --dry-run ────────────────────────────────────────────────────────────

@test "AC4: --dry-run with current PID prints config and exits 0" {
  run bash "$SCRIPT" --dry-run --pid "$$"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
  [[ "$output" == *"pid=$$"* ]]
}

@test "AC4b: --dry-run with --log shows mode=log-mtime" {
  run bash "$SCRIPT" --dry-run --pid "$$" --log "/tmp/fake.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *"mode=log-mtime"* ]]
}

# ── AC5: exit 2 when PID does not exist ──────────────────────────────────────

@test "AC5a: non-existent PID exits 2 immediately" {
  run bash "$SCRIPT" --pid 99999999
  [ "$status" -eq 2 ]
}

@test "AC5b: output mentions dead or pid not found for missing PID" {
  run bash "$SCRIPT" --pid 99999999
  [[ "$output" == *"dead"* ]] || [[ "$output" == *"pid=99999999"* ]]
}

# ── AC6: exit 3 on missing required args ──────────────────────────────────────

@test "AC6a: no args → exit 3" {
  run bash "$SCRIPT"
  [ "$status" -eq 3 ]
}

@test "AC6b: --pid without value → exit 3" {
  run bash "$SCRIPT" --pid
  [ "$status" -eq 3 ]
}

@test "AC6c: unknown flag → exit 3" {
  run bash "$SCRIPT" --pid 99999 --nonexistent-flag
  [ "$status" -eq 3 ]
}

# ── AC7: --json output ────────────────────────────────────────────────────────

@test "AC7: --json with missing PID emits valid JSON with status=dead" {
  run bash "$SCRIPT" --pid 99999999 --json
  [ "$status" -eq 2 ]
  [[ "$output" == *'"status":"dead"'* ]]
  [[ "$output" == *'"pid":'* ]]
  [[ "$output" == *'"elapsed":'* ]]
}

# ── AC8: --timeout respected (must not hang > N+2s) ─────────────────────────

@test "AC8: --timeout 3 exits within 5s for a real but idle-free PID" {
  # Start a long-running process
  sleep 60 &
  LONG_PID=$!
  # Use a very short idle-threshold so it times out, not idles
  local start_t; start_t=$(date +%s)
  run bash "$SCRIPT" --pid "$LONG_PID" --timeout 3 --poll-interval 1 --idle-threshold 60
  local end_t; end_t=$(date +%s)
  kill "$LONG_PID" 2>/dev/null || true
  # Must have exited with status 1 (timeout)
  [ "$status" -eq 1 ]
  # Must have completed within 3+2=5 seconds
  local elapsed=$(( end_t - start_t ))
  [ "$elapsed" -le 5 ]
}

# ── AC9: idle-threshold configurable ─────────────────────────────────────────

@test "AC9: --idle-threshold 2 detects idle faster than default threshold" {
  # Start a process that does nothing (idle immediately)
  sleep 60 &
  IDLE_PID=$!
  run bash "$SCRIPT" --pid "$IDLE_PID" --timeout 15 --poll-interval 1 --idle-threshold 2
  kill "$IDLE_PID" 2>/dev/null || true
  # Should exit 0 (idle) since the process wrote nothing
  [ "$status" -eq 0 ]
}

# ── AC10: PID=0 handled ───────────────────────────────────────────────────────

@test "AC10: PID=0 exits 3 with error message" {
  run bash "$SCRIPT" --pid 0
  [ "$status" -eq 3 ]
  [[ "$output" == *"PID 0"* ]]
}

# ── AC11: missing log file handled gracefully ─────────────────────────────────

@test "AC11: --log pointing to non-existent file is handled without crash" {
  sleep 60 &
  LOG_PID=$!
  # Use a log file that doesn't exist; should still work (Mode A returns 0)
  run bash "$SCRIPT" --pid "$LOG_PID" \
    --log "$TMPDIR_TEST/nonexistent.log" \
    --timeout 6 --poll-interval 1 --idle-threshold 3
  kill "$LOG_PID" 2>/dev/null || true
  # Should exit 0 (idle — no log activity) or 1 (timeout), never crash (3+)
  [ "$status" -le 2 ]
}

# ── AC12: protocol doc exists ─────────────────────────────────────────────────

@test "AC12: agent-idle-protocol.md exists in domain rules" {
  [ -f "$BATS_TEST_DIRNAME/../docs/rules/domain/agent-idle-protocol.md" ]
}

@test "AC12b: protocol doc has SE-206 reference" {
  grep -q 'SE-206' "$BATS_TEST_DIRNAME/../docs/rules/domain/agent-idle-protocol.md"
}

# ── AC13: overnight-sprint SKILL mentions agent-wait-idle ─────────────────────

@test "AC13: overnight-sprint SKILL.md mentions agent-wait-idle" {
  grep -q 'agent-wait-idle' \
    "$BATS_TEST_DIRNAME/../.opencode/skills/overnight-sprint/SKILL.md"
}
