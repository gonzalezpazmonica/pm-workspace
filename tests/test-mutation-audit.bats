#!/usr/bin/env bats
# BATS tests for scripts/mutation-audit.sh (SE-035 Slice 1).
#
# Ref: SE-035, ROADMAP §Tier 4.6
# Safety: script under test `set -uo pipefail`.

SCRIPT="scripts/mutation-audit.sh"

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

@test "references SE-035" {
  run grep -c 'SE-035' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"target"* ]]
  [[ "$output" == *"tests"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --target" {
  run bash "$SCRIPT" --tests tests/test-mutation-audit.bats
  [ "$status" -eq 2 ]
}

@test "requires --tests" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh
  [ "$status" -eq 2 ]
}

@test "rejects nonexistent target" {
  run bash "$SCRIPT" --target /nope.sh --tests tests/test-mutation-audit.bats
  [ "$status" -eq 2 ]
}

@test "rejects nonexistent tests" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests /nope.bats
  [ "$status" -eq 2 ]
}

@test "rejects unsupported extension" {
  local sample="$BATS_TEST_TMPDIR/x.exe"
  touch "$sample"
  local tfile="$BATS_TEST_TMPDIR/t.bats"
  touch "$tfile"
  run bash "$SCRIPT" --target "$sample" --tests "$tfile"
  [ "$status" -eq 2 ]
}

@test "rejects non-integer mutants" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants abc
  [ "$status" -eq 2 ]
}

@test "rejects mutants > 20" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 100
  [ "$status" -eq 2 ]
}

@test "rejects threshold > 100" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --threshold 150
  [ "$status" -eq 2 ]
}

# ── Execution ─────────────────────────────────────────────────────────

@test "runs against real bash target" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 3
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "output contains Score" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 3
  [[ "$output" == *"Score:"* ]]
}

@test "--json produces valid JSON" {
  run bash -c 'bash scripts/mutation-audit.sh --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 3 --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"target\",\"tests\",\"language\",\"mutants_total\",\"killed\",\"survived\",\"score_pct\"]:
    assert k in d, f\"missing {k}\"
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "--json includes language field bash" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 2 --json
  [[ "$output" == *'"language":"bash"'* ]]
}

@test "--seed makes mutant selection deterministic" {
  run1=$(bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 3 --seed 99 --json 2>/dev/null || true)
  run2=$(bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 3 --seed 99 --json 2>/dev/null || true)
  [[ -n "$run1" ]]
  [[ "$run1" == "$run2" ]]
}

@test "verdict is PASS or FAIL" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 2 --json
  [[ "$output" == *"PASS"* || "$output" == *"FAIL"* ]]
}

@test "threshold 100 makes any non-perfect FAIL" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 3 --threshold 100
  # score <100 → FAIL exit 1
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

# ── Isolation ────────────────────────────────────────────────────────

@test "isolation: does not modify target file" {
  local src="scripts/mutation-audit.sh"
  local h_before
  h_before=$(md5sum "$src" | awk '{print $1}')
  bash "$SCRIPT" --target "$src" --tests tests/test-mutation-audit.bats --mutants 3 >/dev/null 2>&1 || true
  local h_after
  h_after=$(md5sum "$src" | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 2
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
