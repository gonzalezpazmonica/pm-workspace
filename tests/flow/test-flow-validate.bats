#!/usr/bin/env bats
# Smoke test for /flow-validate wrapper — Slice 1 of SPEC-AGENTIC-FLOW-GRAPH.

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
  # shellcheck disable=SC1091
  source scripts/savia-env.sh >/dev/null 2>&1 || true
}

@test "validator exists and is executable" {
  [ -x scripts/flow_validate.py ]
}

@test "schema file exists" {
  [ -f schemas/flow.schema.json ]
}

@test "hello-world flow validates OK" {
  run python3 scripts/flow_validate.py hello-world
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK]"* ]]
}

@test "validate all flows passes" {
  run python3 scripts/flow_validate.py all
  [ "$status" -eq 0 ]
}
