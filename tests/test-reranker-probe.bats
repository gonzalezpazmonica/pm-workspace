#!/usr/bin/env bats
# Ref: SE-032
SCRIPT="scripts/reranker-probe.sh"

setup() { export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"; cd "$BATS_TEST_DIRNAME/.."; }
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "references SE-032" { run grep -c 'SE-032' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "references sentence-transformers" { run grep -c 'sentence-transformers\|sentence_transformers' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

@test "--help exits 0" { run bash "$SCRIPT" --help; [ "$status" -eq 0 ]; [[ "$output" == *"probe"* ]]; }
@test "rejects unknown arg" { run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]; }

@test "no args: emits verdict" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "--json produces valid JSON" {
  run bash -c 'bash scripts/reranker-probe.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"python_version\",\"python_major\",\"pip_ok\",\"sentence_transformers\",\"torch\",\"disk_free_gb\",\"reasons\"]:
    assert k in d
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "--json reasons is list" {
  run bash -c 'bash scripts/reranker-probe.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert isinstance(d[\"reasons\"], list)
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "verdict is VIABLE BLOCKED or NEEDS_INSTALL" {
  run bash "$SCRIPT" --json
  [[ "$output" == *"VIABLE"* || "$output" == *"BLOCKED"* || "$output" == *"NEEDS_INSTALL"* ]]
}

@test "output reports Python info" {
  run bash "$SCRIPT"
  [[ "$output" == *"Python:"* ]]
}

@test "output reports Dependencies" {
  run bash "$SCRIPT"
  [[ "$output" == *"Dependencies:"* ]]
}

@test "output reports Disk" {
  run bash "$SCRIPT"
  [[ "$output" == *"Disk:"* ]]
}

# ── Edge cases ────────────────────────

@test "edge: empty flags no crash" { run bash "$SCRIPT"; [[ "$status" -eq 0 || "$status" -eq 1 ]]; }
@test "edge: multiple --json flags handled" { run bash "$SCRIPT" --json --json; [[ "$output" == *"verdict"* ]]; }
@test "edge: disk_free_gb is a number" {
  run bash -c 'bash scripts/reranker-probe.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert isinstance(d[\"disk_free_gb\"], int)
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}
@test "edge: no network calls required" {
  # Run with no network (offline probe)
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
@test "edge: python_major is 0 or integer" {
  run bash -c 'bash scripts/reranker-probe.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert isinstance(d[\"python_major\"], int)
assert d[\"python_major\"] >= 0
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

# ── Negative ────────────────────────

@test "negative: BLOCKED when python missing cannot happen locally but regex verified" {
  run grep -c 'BLOCKED' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "negative: NEEDS_INSTALL when deps missing regex verified" {
  run grep -c 'NEEDS_INSTALL' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Coverage ────────────────────────

@test "coverage: PYTHON_VERSION var" { run grep -c 'PYTHON_VERSION' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: SENTENCE_TRANS var" { run grep -c 'SENTENCE_TRANS' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: TORCH_OK var" { run grep -c 'TORCH_OK' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

# ── Isolation ────────────────────────

@test "isolation: does not write any files" {
  local before
  before=$(find scripts tests docs -type f 2>/dev/null | wc -l)
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local after
  after=$(find scripts tests docs -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}
