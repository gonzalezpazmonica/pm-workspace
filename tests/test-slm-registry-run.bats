#!/usr/bin/env bats
# BATS tests for slm-registry.sh run (SE-342 S2 / Labs L18)
# Ref: SE-342 S2, hypothesis l18-experiment-tracking.md, CRIT-001

SCRIPT="scripts/slm-registry.sh"
CATALOG="scripts/savia-catalog.py"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  TMP_PROJ="$(mktemp -d -t reg.XXXXXX)"
  export SAVIA_CATALOG_DB="$(mktemp -t cat.XXXXXX.db)"
  rm -f "$SAVIA_CATALOG_DB"
  python3 "$CATALOG" register --type dataset --name agent_data --level N2 >/dev/null
}

teardown() {
  rm -rf "$TMP_PROJ"
  [[ -n "${SAVIA_CATALOG_DB:-}" ]] && rm -f "$SAVIA_CATALOG_DB"
  cd /
}

@test "script exists and executable" {
  [[ -x "$SCRIPT" ]]
}

@test "passes bash -n" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "run logs metrics+params to manifest" {
  run bash "$SCRIPT" run --project "$TMP_PROJ" --run-id exp-001 \
    --base-model llama3.2-1b \
    --metrics '{"final_loss": 0.82}' --params '{"epochs": 3}'
  [ "$status" -eq 0 ]
  json="$(cat "$TMP_PROJ/registry/manifest.json")"
  [[ "$json" == *"\"id\": \"exp-001\""* ]]
  [[ "$json" == *"\"final_loss\": 0.82"* ]]
  [[ "$json" == *"\"epochs\": 3"* ]]
}

@test "run without run-id rejected (exit 2)" {
  run bash "$SCRIPT" run --project "$TMP_PROJ"
  [ "$status" -eq 2 ]
}

@test "duplicate run rejected (exit 1)" {
  bash "$SCRIPT" run --project "$TMP_PROJ" --run-id exp-001 >/dev/null
  run bash "$SCRIPT" run --project "$TMP_PROJ" --run-id exp-001
  [ "$status" -eq 1 ]
}

@test "run with dataset writes lineage to L17 catalog" {
  run bash "$SCRIPT" run --project "$TMP_PROJ" --run-id exp-002 \
    --artifact adapters/sft-v1 --dataset agent_data --catalog-db "$SAVIA_CATALOG_DB"
  [ "$status" -eq 0 ]
  run python3 "$CATALOG" --db "$SAVIA_CATALOG_DB" lineage --name "run:exp-002"
  [ "$status" -eq 0 ]
  [[ "$output" == *"agent_data"* ]]
}