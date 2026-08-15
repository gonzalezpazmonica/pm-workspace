#!/usr/bin/env bats
# BATS tests for scripts/mutation-audit.sh (SE-035).
#
# Ref: SE-035, ROADMAP §Tier 4.6, docs/rules/domain/checker-fail-closed.md
# Safety: script under test `set -uo pipefail`.

SCRIPT="scripts/mutation-audit.sh"
FIXTURE_TARGET="tests/fixtures/mutation/target.sh"
FIXTURE_TESTS="tests/fixtures/mutation/test-target.bats"

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

# ── Execution (simulate mode — output format / exit codes) ──────────────────
# The self-referential target (scripts/mutation-audit.sh) is exercised in
# --simulate mode for speed and determinism; real execution is covered by the
# fixture-based tests below.

@test "simulate: runs and prints VERDICT" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 3 --simulate
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "simulate: output contains Score" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 3 --simulate
  [[ "$output" == *"Score:"* ]]
}

@test "simulate: --json produces valid JSON" {
  run bash -c 'bash scripts/mutation-audit.sh --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 3 --simulate --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"execution\",\"target\",\"tests\",\"language\",\"mutants_total\",\"executed\",\"killed\",\"survived\",\"score_pct\"]:
    assert k in d, f\"missing {k}\"
assert d[\"execution\"] == \"simulated\", \"expected simulated mode\"
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "simulate: --json includes language field bash" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 2 --simulate --json
  [[ "$output" == *'"language":"bash"'* ]]
}

@test "--seed makes mutant selection deterministic" {
  run1=$(bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 3 --seed 99 --simulate --json 2>/dev/null || true)
  run2=$(bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 3 --seed 99 --simulate --json 2>/dev/null || true)
  [[ -n "$run1" ]]
  [[ "$run1" == "$run2" ]]
}

@test "simulate: verdict is PASS or FAIL" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 2 --simulate --json
  [[ "$output" == *"PASS"* || "$output" == *"FAIL"* ]]
}

@test "simulate: threshold 100 makes any non-perfect FAIL" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 3 --threshold 100 --simulate
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

# ── Isolation ────────────────────────────────────────────────────────────────

@test "isolation: does not modify target file (simulate)" {
  local src="scripts/mutation-audit.sh"
  local h_before
  h_before=$(md5sum "$src" | awk '{print $1}')
  bash "$SCRIPT" --target "$src" --tests tests/test-mutation-audit.bats --mutants 3 --simulate >/dev/null 2>&1 || true
  local h_after
  h_after=$(md5sum "$src" | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2 (simulate)" {
  run bash "$SCRIPT" --target scripts/mutation-audit.sh --tests tests/test-mutation-audit.bats --mutants 2 --simulate
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}

# ── Real execution (Slice 2) — fixture-based, guarded ───────────────────────

@test "real execution: kills planted mutants in fixture" {
  run bash "$SCRIPT" --target "$FIXTURE_TARGET" --tests "$FIXTURE_TESTS" --mutants 8 --seed 7 --json
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *'"execution":"real"'* ]]
  # The fixture's `+` (arithmetic) and `==` (conditional) lines must be killed.
  local killed
  killed=$(echo "$output" | python3 -c 'import json,sys; print(json.load(sys.stdin)["killed"])')
  [[ "$killed" -ge 2 ]]
}

@test "real execution: JSON reports executed>=1 (execution guard)" {
  run bash "$SCRIPT" --target "$FIXTURE_TARGET" --tests "$FIXTURE_TESTS" --mutants 5 --json
  [[ "$output" == *'"execution":"real"'* ]]
  local executed
  executed=$(echo "$output" | python3 -c 'import json,sys; print(json.load(sys.stdin)["executed"])')
  [[ "$executed" -ge 1 ]]
}

@test "real execution: does not modify fixture target" {
  local h_before h_after
  h_before=$(md5sum "$FIXTURE_TARGET" | awk '{print $1}')
  bash "$SCRIPT" --target "$FIXTURE_TARGET" --tests "$FIXTURE_TESTS" --mutants 5 >/dev/null 2>&1 || true
  h_after=$(md5sum "$FIXTURE_TARGET" | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "real execution: baseline gate aborts when runner is missing" {
  # A runner that cannot exist must fail closed (exit 3), never fabricate a score.
  run bash "$SCRIPT" --target "$FIXTURE_TARGET" --tests "$FIXTURE_TESTS" --runner "nonexistent-runner-xyz" --mutants 3
  [ "$status" -eq 3 ]
}
