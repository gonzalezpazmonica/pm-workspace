#!/usr/bin/env bats
# Tests for SPEC-199: Historical Context Conditioning CLI + iterate.sh integration
# Ref: docs/propuestas/SPEC-199-historical-context-tribunal-rounds.md

HC_SCRIPT="$BATS_TEST_DIRNAME/../scripts/recommendation-tribunal/historical-context.py"
MIGRATE_SCRIPT="$BATS_TEST_DIRNAME/../scripts/kg-schema-migrate-tribunal.py"
ITERATE_SCRIPT="$BATS_TEST_DIRNAME/../scripts/recommendation-tribunal/iterate.sh"

setup() {
  export TMP_TEST_DIR
  TMP_TEST_DIR=$(mktemp -d)
  export SAVIA_TRIBUNAL_HIST_DB="$TMP_TEST_DIR/tribunal-test.db"
  export SAVIA_TRIBUNAL_HIST_MAX_TOKENS=500
}

teardown() {
  rm -rf "$TMP_TEST_DIR"
}

# Test 1: CLI exists and runs without error with empty DB

@test "historical-context: CLI runs without error (empty DB)" {
  run python3 "$HC_SCRIPT" --draft "test draft" --top-k 3
  [ "$status" -eq 0 ]
}

# Test 2: Output is valid JSON

@test "historical-context: output is valid JSON" {
  run python3 "$HC_SCRIPT" --draft "test spec draft text" --top-k 3
  [ "$status" -eq 0 ]
  run python3 -c "import json; json.loads('$output')"
  [ "$status" -eq 0 ]
}

# Test 3: --top-k 0 returns JSON with similar_drafts empty

@test "historical-context: --top-k 0 returns empty similar_drafts" {
  run python3 "$HC_SCRIPT" --draft "some draft" --top-k 0
  [ "$status" -eq 0 ]
  count=$(python3 -c "import json; d=json.loads('$output'); print(len(d['similar_drafts']))")
  [ "$count" -eq 0 ]
}

# Test 4: is_zero_sc present in output

@test "historical-context: is_zero_sc key present in output" {
  run python3 "$HC_SCRIPT" --draft "first draft ever" --top-k 3
  [ "$status" -eq 0 ]
  run python3 -c "import json; d=json.loads('$output'); assert 'is_zero_sc' in d"
  [ "$status" -eq 0 ]
}

# Test 5: SAVIA_TRIBUNAL_HIST_CONTEXT=off does not break iterate.sh

@test "iterate.sh: SAVIA_TRIBUNAL_HIST_CONTEXT=off does not break evaluate-stop" {
  run bash "$ITERATE_SCRIPT"
  [ "$status" -eq 0 ]
  run python3 -c "import json; d=json.loads('$output'); assert d['enabled'] is False"
  [ "$status" -eq 0 ]
}

# Test 6: Schema migration CLI runs and produces valid JSON

@test "kg-schema-migrate-tribunal: CLI runs and produces valid JSON" {
  run python3 "$MIGRATE_SCRIPT" --db "$TMP_TEST_DIR/migrate-test.db" --json
  [ "$status" -eq 0 ]
  run python3 -c "import json; d=json.loads('$output'); assert d['migrated'] is True"
  [ "$status" -eq 0 ]
}
