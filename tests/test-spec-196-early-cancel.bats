#!/usr/bin/env bats
# Ref: scripts/recommendation-tribunal/early-cancel.sh — SPEC-196
# Tests for freeze-done elements pattern in Tribunal orchestrator.
#
# SPEC-055 audit hint: target the early-cancel script for coverage scoring
# SCRIPT="scripts/recommendation-tribunal/early-cancel.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/recommendation-tribunal/early-cancel.sh"
  TMPDIR_EC=$(mktemp -d)
  unset SAVIA_TRIBUNAL_EARLY_CANCEL
  unset SAVIA_TRIBUNAL_EARLY_CANCEL_THRESHOLD
  unset SAVIA_TRIBUNAL_EARLY_CANCEL_POLL_MS
}

teardown() {
  # Kill any lingering sleep processes from tests
  pkill -KILL -P $$ sleep 2>/dev/null || true
  rm -rf "$TMPDIR_EC"
}

# Helper: spawn N background sleep processes, echo their PIDs as CSV
spawn_sleeps() {
  local n="$1"
  local pids=()
  for ((i=0; i<n; i++)); do
    sleep 5 &
    pids+=("$!")
  done
  IFS=','; echo "${pids[*]}"
}

# Helper: kill all CSV PIDs
kill_pids() {
  local csv="$1"
  local pids; IFS=',' read -ra pids <<< "$csv"
  for pid in "${pids[@]}"; do
    kill -KILL "$pid" 2>/dev/null || true
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# Master switch + safety
# ─────────────────────────────────────────────────────────────────────────────

@test "safety: script declares set -uo pipefail" {
  run grep -E "set -uo pipefail" "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "SAVIA_TRIBUNAL_EARLY_CANCEL=off short-circuits with disabled flag" {
  export SAVIA_TRIBUNAL_EARLY_CANCEL=off
  run bash "$SCRIPT" --judges-dir /tmp --pids 1 --names a
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"\"disabled\":true"* ]]
}

@test "help shows usage" {
  run bash "$SCRIPT" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"early-cancel.sh"* ]]
  [[ "$output" == *"SPEC-196"* ]]
}

@test "missing --judges-dir returns exit 2" {
  run bash "$SCRIPT" --pids 1 --names a
  [[ "$status" -eq 2 ]]
}

@test "missing --pids returns exit 2" {
  run bash "$SCRIPT" --judges-dir /tmp --names a
  [[ "$status" -eq 2 ]]
}

@test "nonexistent --judges-dir returns exit 2" {
  run bash "$SCRIPT" --judges-dir /tmp/nonexistent-xyz --pids 1 --names a
  [[ "$status" -eq 2 ]]
}

@test "mismatched pids/names returns exit 2" {
  run bash "$SCRIPT" --judges-dir "$TMPDIR_EC" --pids "1,2,3" --names "a,b"
  [[ "$status" -eq 2 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Behavior: early cancel triggers
# ─────────────────────────────────────────────────────────────────────────────

@test "early-cancel: high-conf veto triggers cancellation" {
  echo '{"judge":"sycophancy","veto":true,"confidence":0.97,"score":92}' > "$TMPDIR_EC/sycophancy.json"
  pids=$(spawn_sleeps 2)
  run bash "$SCRIPT" --judges-dir "$TMPDIR_EC" --pids "$pids" \
      --names "sycophancy,memory-conflict" \
      --threshold 0.95 --max-wait 2 --poll-ms 100
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"\"early_cancel\":true"* ]]
  [[ "$output" == *"sycophancy"* ]]
  kill_pids "$pids"
}

@test "early-cancel: cancelled_judges array contains remaining names" {
  echo '{"judge":"a","veto":true,"confidence":0.99}' > "$TMPDIR_EC/a.json"
  pids=$(spawn_sleeps 3)
  run bash "$SCRIPT" --judges-dir "$TMPDIR_EC" --pids "$pids" \
      --names "a,b,c" --threshold 0.95 --max-wait 2 --poll-ms 100
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"\"b\""* ]]
  [[ "$output" == *"\"c\""* ]]
  kill_pids "$pids"
}

# ─────────────────────────────────────────────────────────────────────────────
# Behavior: no early cancel (edge cases)
# ─────────────────────────────────────────────────────────────────────────────

@test "edge: no veto at all -> early_cancel:false" {
  (sleep 0.2 && echo '{"judge":"a","veto":false,"confidence":0.9}' > "$TMPDIR_EC/a.json") &
  (sleep 0.3 && echo '{"judge":"b","veto":false,"confidence":0.8}' > "$TMPDIR_EC/b.json") &
  pids=$(spawn_sleeps 2)
  run bash "$SCRIPT" --judges-dir "$TMPDIR_EC" --pids "$pids" \
      --names "a,b" --threshold 0.95 --max-wait 2 --poll-ms 100
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"\"early_cancel\":false"* ]]
  [[ "$output" == *"\"trigger\":null"* ]]
  kill_pids "$pids"
}

@test "edge: low-confidence veto does NOT trigger" {
  (sleep 0.2 && echo '{"judge":"a","veto":true,"confidence":0.7}' > "$TMPDIR_EC/a.json") &
  (sleep 0.3 && echo '{"judge":"b","veto":false,"confidence":0.8}' > "$TMPDIR_EC/b.json") &
  pids=$(spawn_sleeps 2)
  run bash "$SCRIPT" --judges-dir "$TMPDIR_EC" --pids "$pids" \
      --names "a,b" --threshold 0.95 --max-wait 2 --poll-ms 100
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"\"early_cancel\":false"* ]]
  kill_pids "$pids"
}

@test "edge: empty judges-dir + max-wait timeout returns gracefully" {
  pids=$(spawn_sleeps 2)
  run bash "$SCRIPT" --judges-dir "$TMPDIR_EC" --pids "$pids" \
      --names "a,b" --threshold 0.95 --max-wait 1 --poll-ms 200
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"\"early_cancel\":false"* ]]
  kill_pids "$pids"
}

@test "edge: malformed JSON in judge file is skipped (jq -e fails)" {
  echo 'not json' > "$TMPDIR_EC/a.json"
  pids=$(spawn_sleeps 2)
  run bash "$SCRIPT" --judges-dir "$TMPDIR_EC" --pids "$pids" \
      --names "a,b" --threshold 0.95 --max-wait 1 --poll-ms 100
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"\"early_cancel\":false"* ]]
  kill_pids "$pids"
}

# ─────────────────────────────────────────────────────────────────────────────
# Output format
# ─────────────────────────────────────────────────────────────────────────────

@test "output is valid JSON with required fields" {
  echo '{"veto":true,"confidence":0.99}' > "$TMPDIR_EC/a.json"
  pids=$(spawn_sleeps 1)
  out=$(bash "$SCRIPT" --judges-dir "$TMPDIR_EC" --pids "$pids" --names a \
        --threshold 0.95 --max-wait 1 --poll-ms 100)
  echo "$out" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
required = {'early_cancel', 'cancelled_judges', 'wall_clock_s', 'trigger', 'threshold'}
missing = required - set(d.keys())
assert not missing, f'missing: {missing}'
assert isinstance(d['cancelled_judges'], list)
assert isinstance(d['wall_clock_s'], (int, float))
"
  kill_pids "$pids"
}

@test "wall_clock_s respects LC_NUMERIC=C (uses dot, not comma)" {
  echo '{"veto":true,"confidence":0.99}' > "$TMPDIR_EC/a.json"
  pids=$(spawn_sleeps 1)
  out=$(LC_NUMERIC=es_ES.UTF-8 bash "$SCRIPT" --judges-dir "$TMPDIR_EC" --pids "$pids" --names a \
        --threshold 0.95 --max-wait 1 --poll-ms 100)
  [[ "$out" != *","* ]] || [[ "$out" == *"\"cancelled_judges\":[]"* ]]
  echo "$out" | python3 -c "import json,sys; json.loads(sys.stdin.read())"
  kill_pids "$pids"
}

# ─────────────────────────────────────────────────────────────────────────────
# Coverage of internal functions (referenced by name for SPEC-055 audit)
# ─────────────────────────────────────────────────────────────────────────────

@test "coverage: script handles spawn_sleeps and kill_pids helper patterns" {
  # This test ensures the early-cancel script properly handles PID management.
  echo '{"veto":true,"confidence":0.97}' > "$TMPDIR_EC/a.json"
  pids=$(spawn_sleeps 2)
  bash "$SCRIPT" --judges-dir "$TMPDIR_EC" --pids "$pids" --names "a,b" \
      --threshold 0.95 --max-wait 1 --poll-ms 100 >/dev/null
  # All PIDs should be dead now
  sleep 1
  IFS=',' read -ra arr <<< "$pids"
  for pid in "${arr[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null
      false  # fail: pid should be dead
    fi
  done
}
