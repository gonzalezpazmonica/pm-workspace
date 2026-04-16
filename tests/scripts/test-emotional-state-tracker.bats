#!/usr/bin/env bats
# Tests for emotional-state-tracker.sh
# Savia Emotional Regulation System — state tracking
# Ref: docs/rules/domain/emotional-regulation.md

setup() {
  TMPDIR=$(mktemp -d)
  export HOME="$TMPDIR"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TRACKER="$REPO_ROOT/scripts/emotional-state-tracker.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "tracker has safety flags" {
  grep -q "set -uo pipefail" "$TRACKER"
}

@test "reset creates clean state file" {
  run bash "$TRACKER" reset
  [ "$status" -eq 0 ]
  [[ "$output" == *"State reset"* ]]
  [ -f "$TMPDIR/.savia/session-stress.json" ]
}

@test "record retry increments counter" {
  bash "$TRACKER" reset
  run bash "$TRACKER" record retry
  [ "$status" -eq 0 ]
  [[ "$output" == *"count: 1"* ]]
  run bash "$TRACKER" record retry
  [[ "$output" == *"count: 2"* ]]
}

@test "record failure increments counter" {
  bash "$TRACKER" reset
  run bash "$TRACKER" record failure
  [ "$status" -eq 0 ]
  [[ "$output" == *"count: 1"* ]]
}

@test "record unknown event fails" {
  bash "$TRACKER" reset
  run bash "$TRACKER" record unknown_event
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown event"* ]]
}

@test "record without event name fails" {
  bash "$TRACKER" reset
  run bash "$TRACKER" record
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

@test "score returns 0 for clean session" {
  bash "$TRACKER" reset
  run bash "$TRACKER" score
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "score returns low for mild friction (2 retries)" {
  bash "$TRACKER" reset
  bash "$TRACKER" record retry
  bash "$TRACKER" record retry
  run bash "$TRACKER" score
  [ "$status" -eq 0 ]
  local score="$output"
  [ "$score" -le 2 ]
}

@test "score returns 5+ for significant friction" {
  bash "$TRACKER" reset
  for i in 1 2 3 4 5; do bash "$TRACKER" record retry; done
  bash "$TRACKER" record failure
  bash "$TRACKER" record failure
  bash "$TRACKER" record escalation
  run bash "$TRACKER" score
  [ "$status" -eq 0 ]
  local score="$output"
  [ "$score" -ge 5 ]
}

@test "score caps at 10" {
  bash "$TRACKER" reset
  for i in $(seq 1 20); do bash "$TRACKER" record failure; done
  for i in $(seq 1 10); do bash "$TRACKER" record escalation; done
  run bash "$TRACKER" score
  [ "$status" -eq 0 ]
  [ "$output" = "10" ]
}

@test "status shows all counters and level" {
  bash "$TRACKER" reset
  bash "$TRACKER" record retry
  bash "$TRACKER" record failure
  run bash "$TRACKER" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Frustration score:"* ]]
  [[ "$output" == *"retry:"* ]]
  [[ "$output" == *"failure:"* ]]
  [[ "$output" == *"escalation:"* ]]
}

@test "status shows calm for clean session" {
  bash "$TRACKER" reset
  run bash "$TRACKER" status
  [[ "$output" == *"calm"* ]]
}

@test "status shows significant_friction at score 5+" {
  bash "$TRACKER" reset
  for i in 1 2 3 4 5; do bash "$TRACKER" record retry; done
  bash "$TRACKER" record failure
  bash "$TRACKER" record failure
  bash "$TRACKER" record escalation
  run bash "$TRACKER" status
  [[ "$output" == *"significant_friction"* ]] || [[ "$output" == *"high_stress"* ]]
}

@test "missing state file is created automatically" {
  run bash "$TRACKER" status
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/.savia/session-stress.json" ]
}

@test "reset after events clears all counters" {
  bash "$TRACKER" record retry
  bash "$TRACKER" record failure
  bash "$TRACKER" reset
  run bash "$TRACKER" score
  [ "$output" = "0" ]
}

@test "last_event is recorded with timestamp" {
  bash "$TRACKER" reset
  bash "$TRACKER" record escalation
  run bash "$TRACKER" status
  [[ "$output" == *"last_event:"*"escalation@"* ]]
}

@test "all five event types are accepted" {
  bash "$TRACKER" reset
  for event in retry failure escalation context_high rule_skip; do
    run bash "$TRACKER" record "$event"
    [ "$status" -eq 0 ]
  done
}

@test "invalid command shows usage" {
  run bash "$TRACKER" invalid_cmd
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}
