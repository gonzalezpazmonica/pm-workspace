#!/usr/bin/env bats
# tests/test-layer-baseline-test.bats — SE-348: criterion 7 baseline test
# Ref: docs/propuestas/SE-348-resiliencia-baseline-capas.md

BASELINE_TEST="${BATS_TEST_DIRNAME}/../scripts/layer-baseline-test.sh"

setup() {
  set -uo pipefail
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

write_metrics() {
  local file="$1"
  local content="$2"
  printf '%s' "$content" > "$file"
}

@test "SE-348 JUSTIFIED: delta above min-delta → exit 0" {
  FULL="$TMP_DIR/full.json"
  BASE="$TMP_DIR/base.json"
  write_metrics "$FULL" '{"a":0.8,"b":0.9}'
  write_metrics "$BASE" '{"a":0.7,"b":0.8}'
  run bash "$BASELINE_TEST" --full-metrics "$FULL" --baseline-metrics "$BASE" --min-delta 0.05
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "JUSTIFIED"
}

@test "SE-348 UNJUSTIFIED: delta below min-delta → exit 1" {
  FULL="$TMP_DIR/full.json"
  BASE="$TMP_DIR/base.json"
  write_metrics "$FULL" '{"a":0.72}'
  write_metrics "$BASE" '{"a":0.70}'
  run bash "$BASELINE_TEST" --full-metrics "$FULL" --baseline-metrics "$BASE" --min-delta 0.05
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "UNJUSTIFIED"
}

@test "SE-348 cost-multiplier 2.0: delta 0.11 JUSTIFIED, delta 0.10 UNJUSTIFIED (strict >)" {
  FULL="$TMP_DIR/full.json"
  BASE="$TMP_DIR/base.json"
  write_metrics "$BASE" '{"a":0.70}'
  write_metrics "$FULL" '{"a":0.81}'
  run bash "$BASELINE_TEST" --full-metrics "$FULL" --baseline-metrics "$BASE" --min-delta 0.05 --cost-multiplier 2.0
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "JUSTIFIED"
  echo "$output" | grep -q "Effective threshold: 0.1"

  write_metrics "$FULL" '{"a":0.80}'
  run bash "$BASELINE_TEST" --full-metrics "$FULL" --baseline-metrics "$BASE" --min-delta 0.05 --cost-multiplier 2.0
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "UNJUSTIFIED"
}

@test "SE-348 missing file → exit 2" {
  run bash "$BASELINE_TEST" --full-metrics "$TMP_DIR/nope.json" --baseline-metrics "$TMP_DIR/also-nope.json"
  [ "$status" -eq 2 ]
}

@test "SE-348 --json emits schema {avg_delta, threshold, status, deltas}" {
  FULL="$TMP_DIR/full.json"
  BASE="$TMP_DIR/base.json"
  write_metrics "$FULL" '{"a":0.8}'
  write_metrics "$BASE" '{"a":0.7}'
  OUT="$(bash "$BASELINE_TEST" --full-metrics "$FULL" --baseline-metrics "$BASE" --min-delta 0.05 --json)"
  echo "$OUT" | jq -e '.status == "JUSTIFIED"'
  echo "$OUT" | jq -e '.avg_delta == 0.1'
  echo "$OUT" | jq -e '.threshold == 0.05'
  echo "$OUT" | jq -e '.deltas | length == 1'
}

@test "SE-348 null and string metrics are ignored" {
  FULL="$TMP_DIR/full.json"
  BASE="$TMP_DIR/base.json"
  write_metrics "$FULL" '{"a":0.8,"x":null,"s":"text"}'
  write_metrics "$BASE" '{"a":0.7,"x":0.9,"s":"other"}'
  OUT="$(bash "$BASELINE_TEST" --full-metrics "$FULL" --baseline-metrics "$BASE" --min-delta 0.05 --json)"
  echo "$OUT" | jq -e '.compared_metrics == 1'
  echo "$OUT" | jq -e '.deltas[0].metric == "a"'
}

@test "SE-348 invalid flag → exit 2" {
  run bash "$BASELINE_TEST" --bogus
  [ "$status" -eq 2 ]
}
