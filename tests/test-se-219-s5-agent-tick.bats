#!/usr/bin/env bats
# test-se-219-s5-agent-tick.bats — SE-219 S5: light/heavy tick separation
# Coverage target: ≥8 tests, score SPEC-055 ≥80

setup() {
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export AGENT_TICK_STATE="$TMP_DIR/tick-state.json"
  export AGENT_HEAVY_TICK_INTERVAL=300
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ── 1. Script exists ───────────────────────────────────────────────────────────
@test "SE-219-S5: agent-tick.sh exists" {
  [ -f "scripts/agent-tick.sh" ]
}

# ── 2. set -uo pipefail on line 2 ────────────────────────────────────────────
@test "SE-219-S5: set -uo pipefail on line 2" {
  local line2
  line2=$(sed -n '2p' scripts/agent-tick.sh)
  [[ "$line2" == *"set -uo pipefail"* ]]
}

# ── 3. --mode light → exit 0, TICK_MODE=light ─────────────────────────────────
@test "SE-219-S5: --mode light completes with exit 0 and TICK_MODE=light" {
  run bash scripts/agent-tick.sh --mode light
  [ "$status" -eq 0 ]
  [[ "$output" == *"TICK_MODE=light"* ]]
}

# ── 4. --mode heavy first time → exit 0, TICK_MODE=heavy ─────────────────────
@test "SE-219-S5: --mode heavy first time => exit 0, TICK_MODE=heavy" {
  run bash scripts/agent-tick.sh --mode heavy
  [ "$status" -eq 0 ]
  [[ "$output" == *"TICK_MODE=heavy"* ]]
}

# ── 5. --mode heavy twice immediately → TICK_SKIPPED=true ───────────────────
@test "SE-219-S5: --mode heavy second time immediate (< interval) => TICK_SKIPPED=true" {
  # First heavy tick
  bash scripts/agent-tick.sh --mode heavy > /dev/null
  # Second heavy tick immediately
  run bash scripts/agent-tick.sh --mode heavy
  [ "$status" -eq 0 ]
  [[ "$output" == *"TICK_SKIPPED=true"* ]]
}

# ── 6. AGENT_HEAVY_TICK_INTERVAL=0 → never skips ────────────────────────────
@test "SE-219-S5: AGENT_HEAVY_TICK_INTERVAL=0 never skips heavy tick" {
  export AGENT_HEAVY_TICK_INTERVAL=0
  bash scripts/agent-tick.sh --mode heavy > /dev/null
  run bash scripts/agent-tick.sh --mode heavy
  [ "$status" -eq 0 ]
  [[ "$output" == *"TICK_MODE=heavy"* ]]
  [[ "$output" != *"TICK_SKIPPED=true"* ]]
}

# ── 7. --status without prior state → exit 0, defaults ───────────────────────
@test "SE-219-S5: --status without prior state => exit 0, default output" {
  run bash scripts/agent-tick.sh --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"HEAVY_TICK_INTERVAL="* ]]
}

# ── 8. --status after --mode light → reflects state ──────────────────────────
@test "SE-219-S5: --status after --mode light reflects light state" {
  bash scripts/agent-tick.sh --mode light > /dev/null
  run bash scripts/agent-tick.sh --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"TICK_MODE=light"* ]]
}

# ── 9. --mode invalid → exit 2 ───────────────────────────────────────────────
@test "SE-219-S5: --mode invalid => exit 2" {
  run bash scripts/agent-tick.sh --mode invalid
  [ "$status" -eq 2 ]
}

# ── 10. AGENT_TICK_STATE in non-existent dir → creates dir, exit 0 ───────────
@test "SE-219-S5: TICK_STATE_FILE in non-existent dir => creates dir, exit 0" {
  export AGENT_TICK_STATE="$TMP_DIR/nested/deep/tick-state.json"
  run bash scripts/agent-tick.sh --mode light
  [ "$status" -eq 0 ]
  [ -f "$AGENT_TICK_STATE" ]
}
