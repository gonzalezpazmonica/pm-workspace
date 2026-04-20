#!/usr/bin/env bats
# BATS tests for scripts/test-auditor-sweep.sh (SE-039 Slice 1).
#
# Ref: SE-039, SPEC-055 test-auditor
# Safety: read-only, set -uo pipefail.

SCRIPT="scripts/test-auditor-sweep.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }

@test "uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }

@test "references SE-039" {
  run grep -c 'SE-039' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "references test-auditor.sh" {
  run grep -c 'test-auditor' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"bottom"* ]]
  [[ "$output" == *"threshold"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "rejects non-integer --bottom" {
  run bash "$SCRIPT" --bottom abc
  [ "$status" -eq 2 ]
}

@test "rejects --bottom 0" {
  run bash "$SCRIPT" --bottom 0
  [ "$status" -eq 2 ]
}

@test "rejects --threshold > 100" {
  run bash "$SCRIPT" --threshold 150
  [ "$status" -eq 2 ]
}

@test "rejects non-integer --threshold" {
  run bash "$SCRIPT" --threshold xyz
  [ "$status" -eq 2 ]
}

# ── Execution ─────────────────────────────────────────────────────────

@test "runs against real tests/ dir" {
  run bash "$SCRIPT" --bottom 3
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "output reports Files scanned" {
  run bash "$SCRIPT" --bottom 3
  [[ "$output" == *"Files scanned:"* ]]
}

@test "output reports Compliance" {
  run bash "$SCRIPT" --bottom 3
  [[ "$output" == *"Compliance:"* ]]
}

@test "output reports Bottom N ranking" {
  run bash "$SCRIPT" --bottom 5
  [[ "$output" == *"Bottom 5"* ]]
}

@test "--filter narrows files" {
  run bash "$SCRIPT" --filter "test-mutation-*.bats"
  [[ "$output" == *"Files scanned:"* ]]
}

@test "--filter with no matches returns 1" {
  run bash "$SCRIPT" --filter "nonexistent-test-xyz-*.bats"
  [ "$status" -eq 1 ]
}

@test "--json produces valid JSON" {
  run bash -c 'bash scripts/test-auditor-sweep.sh --bottom 3 --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"files\",\"compliant\",\"compliance_pct\",\"bottom\"]:
    assert k in d, f\"missing {k}\"
assert isinstance(d[\"bottom\"], list)
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "--json bottom list respects --bottom size" {
  run bash -c 'bash scripts/test-auditor-sweep.sh --bottom 2 --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert len(d[\"bottom\"]) <= 2
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "bottom list sorted ascending by score" {
  run bash -c 'bash scripts/test-auditor-sweep.sh --bottom 10 --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
scores = [b[\"score\"] for b in d[\"bottom\"]]
assert scores == sorted(scores), f\"not sorted: {scores}\"
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "verdict is PASS or FAIL" {
  run bash "$SCRIPT" --bottom 3 --json
  [[ "$output" == *"PASS"* || "$output" == *"FAIL"* ]]
}

@test "compliance_pct between 0 and 100" {
  run bash -c 'bash scripts/test-auditor-sweep.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 0 <= d[\"compliance_pct\"] <= 100
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

# ── Isolation ────────────────────────────────────────────────────────

@test "isolation: does not modify any test file" {
  local h_before
  h_before=$(find tests -name "*.bats" -type f -exec md5sum {} + | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" --bottom 2 >/dev/null 2>&1 || true
  local h_after
  h_after=$(find tests -name "*.bats" -type f -exec md5sum {} + | sort | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT" --bottom 3
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
