#!/usr/bin/env bats
# test-se361-ci-duration.bats — BATS tests for SE-361 ci-duration
# Ref: SE-361 — presupuesto de tiempo de CI (bottleneck explícito)

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  AGG="$REPO_ROOT/scripts/ci-duration-agg.py"
  WRAP="$REPO_ROOT/scripts/ci-duration.sh"
  export REPO_ROOT AGG WRAP
  export TEST_JOBS="$(mktemp -d)"
}

teardown() {
  if [[ -d "${TEST_JOBS:-}" ]]; then
    rm -rf "$TEST_JOBS"
  fi
}

@test "agg con jobs vacíos → JSON válido, 0 over_budget" {
  run python3 "$AGG" --input /no/existe.jsonl --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['jobs'] == {}
assert d['over_budget_count'] == 0
"
}

@test "agg detecta job sobre presupuesto (10min > 5min)" {
  local f="$TEST_JOBS/jobs.jsonl"
  printf '{"name":"BATS","duration_ms":180000,"conclusion":"success"}\n' > "$f"
  printf '{"name":"Lint","duration_ms":600000,"conclusion":"success"}\n' >> "$f"
  run python3 "$AGG" --input "$f" --budget 5 --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['jobs']['Lint']['over_budget'] is True, d
assert d['jobs']['BATS']['over_budget'] is False
assert d['over_budget_count'] == 1
"
}

@test "agg p50/p95 presentes" {
  local f="$TEST_JOBS/jobs.jsonl"
  printf '{"name":"BATS","duration_ms":180000,"conclusion":"success"}\n' > "$f"
  printf '{"name":"BATS","duration_ms":190000,"conclusion":"success"}\n' >> "$f"
  run python3 "$AGG" --input "$f" --budget 5 --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['jobs']['BATS']['p50_ms'] > 0
assert d['jobs']['BATS']['p95_ms'] > 0
"
}

@test "wrapper --offline usa cache local" {
  local f="$TEST_JOBS/jobs.jsonl"
  printf '{"name":"Validate","duration_ms":120000,"conclusion":"success"}\n' > "$f"
  run bash "$WRAP" --offline --budget 5 --format json --input "$f"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Validate"* ]]
}
