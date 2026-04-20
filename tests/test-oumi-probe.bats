#!/usr/bin/env bats
# Ref: SE-028/041/056 + unified runner
SCRIPT="scripts/oumi-probe.sh"

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

@test "references SE-028" { run grep -c 'SE-028' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "references oumi" { run grep -ic 'oumi' "$SCRIPT"; [[ "$output" -ge 3 ]]; }
@test "verdict is VIABLE/BLOCKED/NEEDS_INSTALL" {
  run bash "$SCRIPT" --json
  [[ "$output" == *"VIABLE"* || "$output" == *"BLOCKED"* || "$output" == *"NEEDS_INSTALL"* ]]
}
@test "--json has python_version key" {
  run bash -c 'bash scripts/oumi-probe.sh --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"python_version\" in d; print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}
@test "--json has oumi_installed field" {
  run bash -c 'bash scripts/oumi-probe.sh --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"oumi_installed\" in d; print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}
@test "--json has disk_free_gb" {
  run bash -c 'bash scripts/oumi-probe.sh --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d[\"disk_free_gb\"], int); print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}
@test "edge: reasons is a list" {
  run bash -c 'bash scripts/oumi-probe.sh --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d[\"reasons\"], list); print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}
@test "output reports VERDICT header" {
  run bash "$SCRIPT"
  [[ "$output" == *"VERDICT"* ]]
}
@test "NEEDS_INSTALL path present in script" {
  run grep -c 'NEEDS_INSTALL' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "BLOCKED path present in script" {
  run grep -c 'BLOCKED' "$SCRIPT"
  [[ "$output" -ge 1 ]]
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
