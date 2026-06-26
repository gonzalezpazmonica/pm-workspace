#!/usr/bin/env bats
# tests/bats/test-evals-ci-gate.bats — SPEC-151 BATS tests
# Validates runner, workflow, scripts, and datasets existence.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

@test "evals-runner.sh exists and is executable" {
  local runner="$REPO_ROOT/scripts/evals-runner.sh"
  [ -f "$runner" ]
  [ -x "$runner" ]
}

@test "evals-runner.sh --mock produces valid JSON array" {
  local runner="$REPO_ROOT/scripts/evals-runner.sh"
  run bash "$runner" --mock
  [ "$status" -eq 0 ]
  # Validate it's a JSON array
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert isinstance(data, list), 'Expected JSON array'
assert len(data) > 0, 'Expected non-empty array'
"
  [ "$?" -eq 0 ]
}

@test "evals-ci.yaml workflow exists" {
  local workflow="$REPO_ROOT/.github/workflows/evals-ci.yaml"
  [ -f "$workflow" ]
}

@test "evals-paired-delta.py exists" {
  local script="$REPO_ROOT/scripts/evals-paired-delta.py"
  [ -f "$script" ]
}

@test "tests/evals/datasets directory has jsonl files" {
  local datasets_dir="$REPO_ROOT/tests/evals/datasets"
  [ -d "$datasets_dir" ]
  # At least one .jsonl file must exist
  local count
  count=$(find "$datasets_dir" -name "*.jsonl" | wc -l)
  [ "$count" -ge 1 ]
}

@test "evals-paired-delta.py passes for equal baseline and current" {
  local script="$REPO_ROOT/scripts/evals-paired-delta.py"
  local tmp_scores
  tmp_scores=$(mktemp /tmp/scores-XXXXXX.json)
  echo '[{"id":"t1","score":0.8},{"id":"t2","score":0.9}]' > "$tmp_scores"
  run python3 "$script" --baseline "$tmp_scores" --current "$tmp_scores"
  rm -f "$tmp_scores"
  [ "$status" -eq 0 ]
  # threshold_pass must be true
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['threshold_pass'] is True, f'Expected pass, got {d}'
"
  [ "$?" -eq 0 ]
}
