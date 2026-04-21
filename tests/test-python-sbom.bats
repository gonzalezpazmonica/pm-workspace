#!/usr/bin/env bats
# Ref: SE-028/041/056 + unified runner
SCRIPT="scripts/python-sbom.sh"

setup() { export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"; cd "$BATS_TEST_DIRNAME/.."; }
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "--help exits 0" { run bash "$SCRIPT" --help; [ "$status" -eq 0 ]; }
@test "rejects unknown arg" { run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]; }
@test "runs without crash" { run bash "$SCRIPT"; [[ "$status" -eq 0 || "$status" -eq 1 ]]; }
@test "--json produces output" { run bash "$SCRIPT" --json; [[ "$output" == *"{"* ]]; }
@test "--json parses as JSON" {
  run bash -c 'bash '"$SCRIPT"' --json | python3 -c "import json,sys; json.load(sys.stdin); print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}

@test "references SE-056" { run grep -c 'SE-056' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "references requirements.txt" { run grep -c 'requirements.txt' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "--venv prints instructions" {
  run bash "$SCRIPT" --venv
  [ "$status" -eq 0 ]
  [[ "$output" == *"venv"* ]]
  [[ "$output" == *".savia-venv"* ]]
}
@test "--check flag recognized" {
  run bash "$SCRIPT" --check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
@test "--json has missing list" {
  run bash -c 'bash scripts/python-sbom.sh --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d[\"missing\"], list); print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}
@test "--json has present list" {
  run bash -c 'bash scripts/python-sbom.sh --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d[\"present\"], list); print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}
@test "--json has python_scripts count" {
  run bash -c 'bash scripts/python-sbom.sh --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert d[\"python_scripts\"] > 0; print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}
@test "output reports Python scripts" {
  run bash "$SCRIPT"
  [[ "$output" == *"Python scripts:"* ]]
}
@test "output reports Unique 3P imports" {
  run bash "$SCRIPT"
  [[ "$output" == *"Unique 3P imports:"* ]]
}
@test "coverage: STDLIB_MODULES constant" { run grep -c 'STDLIB_MODULES' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: extract_imports function" { run grep -c 'extract_imports' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "edge: check mode returns exit 1 on drift" {
  # If missing > 0, --check must exit 1
  local missing
  missing=$(bash "$SCRIPT" --json | python3 -c "import json,sys; print(json.load(sys.stdin)['missing_count'])")
  if [[ "$missing" -gt 0 ]]; then
    run bash "$SCRIPT" --check
    [ "$status" -eq 1 ]
  else
    run bash "$SCRIPT" --check
    [ "$status" -eq 0 ]
  fi
}
@test "isolation: no file writes" {
  local before
  before=$(find scripts tests docs -type f 2>/dev/null | wc -l)
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local after
  after=$(find scripts tests docs -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}
@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT"; [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]
}
