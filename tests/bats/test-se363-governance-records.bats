#!/usr/bin/env bats
# test-se363-governance-records.bats — BATS tests for SE-363 records-not-files
# Ref: SE-363 — capa consultable sobre Markdown (registros, no archivos)

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SYNC="$REPO_ROOT/scripts/governance-sync.py"
  export REPO_ROOT SYNC
  export TEST_GOV="$(mktemp -d)"
}

teardown() {
  if [[ -d "${TEST_GOV:-}" ]]; then
    rm -rf "$TEST_GOV"
  fi
}

@test "sync genera registro desde CRITERIO.md" {
  run python3 "$SYNC" sync --source "$REPO_ROOT/CRITERIO.md" --output "$TEST_GOV/criterios.jsonl"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Registro gobernanza"* ]]
  [[ -f "$TEST_GOV/criterios.jsonl" ]]
}

@test "registro es JSONL válido" {
  python3 "$SYNC" sync --source "$REPO_ROOT/CRITERIO.md" --output "$TEST_GOV/criterios.jsonl" >/dev/null
  run python3 -c "
import json
for line in open('$TEST_GOV/criterios.jsonl'):
    line = line.strip()
    if line:
        json.loads(line)
print('OK')
"
  [[ "$status" -eq 0 ]]
}

@test "sync --check pasa con registro up-to-date" {
  python3 "$SYNC" sync --source "$REPO_ROOT/CRITERIO.md" --output "$TEST_GOV/criterios.jsonl" >/dev/null
  run python3 "$SYNC" sync --source "$REPO_ROOT/CRITERIO.md" --output "$TEST_GOV/criterios.jsonl" --check
  [[ "$status" -eq 0 ]]
}

@test "query --status ACTIVE devuelve criterios" {
  python3 "$SYNC" sync --source "$REPO_ROOT/CRITERIO.md" --output "$TEST_GOV/criterios.jsonl" >/dev/null
  run python3 "$SYNC" query --registry "$TEST_GOV/criterios.jsonl" --status ACTIVE --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
rows = json.load(sys.stdin)
assert len(rows) > 0, 'sin criterios ACTIVE'
assert all(r['status'] == 'ACTIVE' for r in rows)
"
}

@test "CRITERIO.md intacto tras sync (no se modifica)" {
  local before after
  before=$(sha256sum "$REPO_ROOT/CRITERIO.md" | cut -d' ' -f1)
  python3 "$SYNC" sync --source "$REPO_ROOT/CRITERIO.md" --output "$TEST_GOV/criterios.jsonl" >/dev/null
  after=$(sha256sum "$REPO_ROOT/CRITERIO.md" | cut -d' ' -f1)
  [[ "$before" == "$after" ]]
}
