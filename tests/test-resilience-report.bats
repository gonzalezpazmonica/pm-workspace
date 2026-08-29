#!/usr/bin/env bats
# tests/test-resilience-report.bats — SE-348: agent resilience metrics report
# Ref: docs/propuestas/SE-348-resiliencia-baseline-capas.md
# Coverage: variance_class (nominal/exploratory/dysfunctional/external),
#   weighted_error, max_consec_errors, t_rec_s, recovered, JSON output, legacy compat.

LOGGER="${BATS_TEST_DIRNAME}/../scripts/agent-run-logger.sh"
REPORT="${BATS_TEST_DIRNAME}/../scripts/resilience-report.sh"

setup() {
  set -uo pipefail
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export AGENT_ACTUALS_LOG="$TMP_DIR/agent-actuals.jsonl"
  export SAVIA_WORKSPACE_DIR="$TMP_DIR"
  touch "$AGENT_ACTUALS_LOG"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

detail_json() {
  local run_id="$1"
  bash "$REPORT" detail "$run_id" --json
}

@test "SE-348 exploratory: completed with error then ok → exploratory, recovered, t_rec != null" {
  RUN_ID="$(bash "$LOGGER" start "se348" "recovery")"
  bash "$LOGGER" tool-call "$RUN_ID" bash error
  bash "$LOGGER" tool-call "$RUN_ID" bash ok
  bash "$LOGGER" finish "$RUN_ID" completed
  OUT="$(detail_json "$RUN_ID")"
  echo "$OUT" | jq -e '.variance_class == "exploratory"'
  echo "$OUT" | jq -e '.recovered == true'
  echo "$OUT" | jq -e '.t_rec_s != null'
}

@test "SE-348 dysfunctional: error then finish error → dysfunctional" {
  RUN_ID="$(bash "$LOGGER" start "se348" "bad")"
  bash "$LOGGER" tool-call "$RUN_ID" bash error
  bash "$LOGGER" finish "$RUN_ID" error
  OUT="$(detail_json "$RUN_ID")"
  echo "$OUT" | jq -e '.variance_class == "dysfunctional"'
}

@test "SE-348 external: aborted with no prior error signals → external" {
  RUN_ID="$(bash "$LOGGER" start "se348" "cut")"
  bash "$LOGGER" finish "$RUN_ID" aborted
  OUT="$(detail_json "$RUN_ID")"
  echo "$OUT" | jq -e '.variance_class == "external"'
  echo "$OUT" | jq -e '.recovered == false'
}

@test "SE-348 nominal: completed with no error signals → nominal, recovered false" {
  RUN_ID="$(bash "$LOGGER" start "se348" "clean")"
  bash "$LOGGER" tool-call "$RUN_ID" read ok
  bash "$LOGGER" finish "$RUN_ID" completed
  OUT="$(detail_json "$RUN_ID")"
  echo "$OUT" | jq -e '.variance_class == "nominal"'
  echo "$OUT" | jq -e '.recovered == false'
}

@test "SE-348 weighted_error: one error (0.9) + one ok (0.0) over 2 calls → 0.45" {
  RUN_ID="$(bash "$LOGGER" start "se348" "weighted")"
  bash "$LOGGER" tool-call "$RUN_ID" bash error
  bash "$LOGGER" tool-call "$RUN_ID" read ok
  bash "$LOGGER" finish "$RUN_ID" completed
  OUT="$(detail_json "$RUN_ID")"
  echo "$OUT" | jq -e '.weighted_error == 0.45'
  echo "$OUT" | jq -e '.error_rate == 0.5'
}

@test "SE-348 max_consec_errors: ok,error,error,ok → 2" {
  RUN_ID="$(bash "$LOGGER" start "se348" "streak")"
  bash "$LOGGER" tool-call "$RUN_ID" a ok
  bash "$LOGGER" tool-call "$RUN_ID" b error
  bash "$LOGGER" tool-call "$RUN_ID" c error
  bash "$LOGGER" tool-call "$RUN_ID" d ok
  bash "$LOGGER" finish "$RUN_ID" completed
  OUT="$(detail_json "$RUN_ID")"
  echo "$OUT" | jq -e '.max_consec_errors == 2'
}

@test "SE-348 summary --json: emits runs and by_agent rollup" {
  RUN_ID="$(bash "$LOGGER" start "se348-agent" "rollup")"
  bash "$LOGGER" tool-call "$RUN_ID" bash error
  bash "$LOGGER" tool-call "$RUN_ID" bash ok
  bash "$LOGGER" finish "$RUN_ID" completed
  OUT="$(bash "$REPORT" summary --json)"
  echo "$OUT" | jq -e '.runs | length == 1'
  echo "$OUT" | jq -e '.by_agent["se348-agent"].variance_classes.exploratory == 1'
  echo "$OUT" | jq -e '.by_agent["se348-agent"].runs == 1'
}

@test "SE-348 empty log: exit 0 with no rows" {
  : > "$AGENT_ACTUALS_LOG"
  run bash "$REPORT" summary
  [ "$status" -eq 0 ]
  run bash "$REPORT" summary --json
  [ "$status" -eq 0 ]
}

@test "SE-348 legacy records (no tool_events) do not break the report" {
  echo '{"spec_id":"SE-001","category":"standard","verdict":"shipped"}' >> "$AGENT_ACTUALS_LOG"
  RUN_ID="$(bash "$LOGGER" start "compat" "legacy coexist")"
  bash "$LOGGER" tool-call "$RUN_ID" bash ok
  bash "$LOGGER" finish "$RUN_ID" completed
  run bash "$REPORT" summary
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "compat"
}

@test "SE-348 detail with unknown run_id: exit 0, message to stderr" {
  run bash "$REPORT" detail "does-not-exist-000"
  [ "$status" -eq 0 ]
}

@test "SE-348 invalid flag: exit 2" {
  run bash "$REPORT" --bogus-flag
  [ "$status" -eq 2 ]
}
