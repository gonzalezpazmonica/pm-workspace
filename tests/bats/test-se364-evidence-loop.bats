#!/usr/bin/env bats
# test-se364-evidence-loop.bats — BATS tests for SE-364 evidence-loop
# Ref: SE-364 — historial de decisiones como corpus de evals

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CAP="$REPO_ROOT/scripts/evidence-capture.py"
  WRAP="$REPO_ROOT/scripts/evidence-capture.sh"
  export REPO_ROOT CAP WRAP
  export TEST_EV="$(mktemp -d)"
}

teardown() {
  if [[ -d "${TEST_EV:-}" ]]; then
    rm -rf "$TEST_EV"
  fi
}

@test "captura casos failure/deny desde audit" {
  local audit="$TEST_EV/audit.jsonl"
  printf '{"action":"pr_merge","outcome":"failure","target":"101"}\n' > "$audit"
  printf '{"action":"pr_merge","outcome":"enforced_deny","target":"102"}\n' >> "$audit"
  run python3 "$CAP" --audit "$audit" --corpus "$TEST_EV/corpus"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Casos capturados"* ]]
  # 2 ficheros en corpus
  run bash -c "ls $TEST_EV/corpus/*.json 2>/dev/null | wc -l"
  [[ "${lines[0]}" -ge 2 ]]
}

@test "wrapper genera evals desde corpus" {
  local audit="$TEST_EV/audit.jsonl"
  printf '{"action":"pr_merge","outcome":"failure","target":"101"}\n' > "$audit"
  python3 "$CAP" --audit "$audit" --corpus "$TEST_EV/corpus" >/dev/null
  run bash "$WRAP" --to-evals --corpus "$TEST_EV/corpus" --output "$TEST_EV/evals.json"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Evals generados"* ]]
  [[ -f "$TEST_EV/evals.json" ]]
}

@test "evals.json es JSON válido con discriminantes" {
  local audit="$TEST_EV/audit.jsonl"
  printf '{"action":"pr_merge","outcome":"failure","target":"101"}\n' > "$audit"
  python3 "$CAP" --audit "$audit" --corpus "$TEST_EV/corpus" >/dev/null
  bash "$WRAP" --to-evals --corpus "$TEST_EV/corpus" --output "$TEST_EV/evals.json" >/dev/null
  run python3 -c "
import json
evals = json.load(open('$TEST_EV/evals.json'))
for e in evals:
    assert 'input' in e and 'output_rejected' in e
print('OK')
"
  [[ "$status" -eq 0 ]]
}

@test "sin intervenciones → corpus vacío, sin fallo" {
  local audit="$TEST_EV/audit.jsonl"
  printf '{"action":"pr_merge","outcome":"success","target":"101"}\n' > "$audit"
  run python3 "$CAP" --audit "$audit" --corpus "$TEST_EV/corpus"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"0"* ]]
}
