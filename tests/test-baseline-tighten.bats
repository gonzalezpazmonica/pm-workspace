#!/usr/bin/env bats
# BATS tests for scripts/baseline-tighten.sh (SE-046 Slice 1).
# Ref: SE-046, audit-arquitectura-20260420.md D6
SCRIPT="scripts/baseline-tighten.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "references SE-046" { run grep -c 'SE-046' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"baseline"* ]]
  [[ "$output" == *"current"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --baseline" {
  run bash "$SCRIPT" --current 5
  [ "$status" -eq 2 ]
}

@test "requires --current" {
  run bash "$SCRIPT" --baseline /tmp/x
  [ "$status" -eq 2 ]
}

@test "rejects non-integer --current" {
  run bash "$SCRIPT" --baseline /tmp/x --current abc
  [ "$status" -eq 2 ]
}

# ── Tighten behavior ────────────────────────────────────────

@test "tightens when current < previous" {
  local b="$BATS_TEST_TMPDIR/baseline"
  echo "10" > "$b"
  run bash "$SCRIPT" --baseline "$b" --current 4
  [ "$status" -eq 0 ]
  [[ "$(cat "$b")" == "4" ]]
}

@test "regression when current > previous" {
  local b="$BATS_TEST_TMPDIR/baseline"
  echo "3" > "$b"
  run bash "$SCRIPT" --baseline "$b" --current 7
  [ "$status" -eq 1 ]
  [[ "$(cat "$b")" == "3" ]]  # unchanged
}

@test "noop when current == previous" {
  local b="$BATS_TEST_TMPDIR/baseline"
  echo "5" > "$b"
  run bash "$SCRIPT" --baseline "$b" --current 5
  [ "$status" -eq 0 ]
  [[ "$(cat "$b")" == "5" ]]
}

@test "creates baseline file when missing (treats as 0)" {
  local b="$BATS_TEST_TMPDIR/new/nested/baseline"
  [[ ! -e "$b" ]]
  run bash "$SCRIPT" --baseline "$b" --current 0
  [ "$status" -eq 0 ]
  # current=0, previous=0 → noop
}

@test "creates dir hierarchy for baseline write" {
  local b="$BATS_TEST_TMPDIR/deeply/new/dir/baseline"
  echo "10" > "$BATS_TEST_TMPDIR/src-baseline"
  # Tighten scenario: previous 10 → current 2 → should write file
  [[ ! -e "$b" ]]
  # We need an existing baseline for tighten path, so:
  mkdir -p "$(dirname "$b")"
  echo "10" > "$b"
  run bash "$SCRIPT" --baseline "$b" --current 2
  [ "$status" -eq 0 ]
  [[ "$(cat "$b")" == "2" ]]
}

@test "--dry-run does not write" {
  local b="$BATS_TEST_TMPDIR/baseline"
  echo "10" > "$b"
  run bash "$SCRIPT" --baseline "$b" --current 3 --dry-run
  [ "$status" -eq 0 ]
  [[ "$(cat "$b")" == "10" ]]  # unchanged
  [[ "$output" == *"dry-run"* ]]
}

@test "--json output valid" {
  local b="$BATS_TEST_TMPDIR/baseline"
  echo "10" > "$b"
  run bash -c 'bash scripts/baseline-tighten.sh --baseline "'"$b"'" --current 4 --dry-run --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"action\",\"baseline_file\",\"previous\",\"current\",\"dry_run\"]:
    assert k in d
assert d[\"action\"] == \"tighten\"
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "--json action: regression" {
  local b="$BATS_TEST_TMPDIR/baseline"
  echo "3" > "$b"
  run bash "$SCRIPT" --baseline "$b" --current 8 --json
  [ "$status" -eq 1 ]
  [[ "$output" == *'"action":"regression"'* ]]
}

@test "--json action: noop" {
  local b="$BATS_TEST_TMPDIR/baseline"
  echo "5" > "$b"
  run bash "$SCRIPT" --baseline "$b" --current 5 --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"action":"noop"'* ]]
}

# ── Regression guard ─────────────────────────────────────

@test "regression: script NEVER loosens baseline" {
  local b="$BATS_TEST_TMPDIR/baseline"
  echo "2" > "$b"
  run bash "$SCRIPT" --baseline "$b" --current 100
  [[ "$(cat "$b")" == "2" ]]  # never grows
}

@test "output reports Action field" {
  local b="$BATS_TEST_TMPDIR/baseline"
  echo "10" > "$b"
  run bash "$SCRIPT" --baseline "$b" --current 4
  [[ "$output" == *"Action:"* ]]
}

@test "isolation: exit codes 0/1/2" {
  local b="$BATS_TEST_TMPDIR/baseline"
  echo "5" > "$b"
  run bash "$SCRIPT" --baseline "$b" --current 2
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" --baseline "$b" --current 100
  [ "$status" -eq 1 ]
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}
