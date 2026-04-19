#!/usr/bin/env bats
# BATS tests for scripts/gaia-benchmark-harness.sh (SPEC-100 Slice 1).
#
# Ref: SPEC-100, ROADMAP §Tier 4.9
# Safety: script under test `set -uo pipefail`.

SCRIPT="scripts/gaia-benchmark-harness.sh"

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

@test "references SPEC-100" {
  run grep -c 'SPEC-100' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "clarifies it does NOT download dataset" {
  run grep -ciE 'NO (descarga|instala)|NOT download|does not download' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"level"* ]]
  [[ "$output" == *"output-dir"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --level" {
  run bash "$SCRIPT" --output-dir "$BATS_TEST_TMPDIR/o"
  [ "$status" -eq 2 ]
}

@test "requires --output-dir" {
  run bash "$SCRIPT" --level L1
  [ "$status" -eq 2 ]
}

@test "rejects invalid level" {
  run bash "$SCRIPT" --level L99 --output-dir "$BATS_TEST_TMPDIR/o"
  [ "$status" -eq 2 ]
}

@test "rejects non-integer n-tasks" {
  run bash "$SCRIPT" --level L1 --output-dir "$BATS_TEST_TMPDIR/o" --n-tasks abc
  [ "$status" -eq 2 ]
}

# ── Scaffolding output ────────────────────────────────────────────────────

@test "generates harness-config.yaml" {
  local out="$BATS_TEST_TMPDIR/o"
  run bash "$SCRIPT" --level L1 --output-dir "$out"
  [ "$status" -eq 0 ]
  [[ -f "$out/harness-config.yaml" ]]
}

@test "generates prompts-subset.jsonl" {
  local out="$BATS_TEST_TMPDIR/o"
  bash "$SCRIPT" --level L1 --output-dir "$out" >/dev/null 2>&1
  [[ -f "$out/prompts-subset.jsonl" ]]
}

@test "generates results-template.json" {
  local out="$BATS_TEST_TMPDIR/o"
  bash "$SCRIPT" --level L1 --output-dir "$out" >/dev/null 2>&1
  [[ -f "$out/results-template.json" ]]
}

@test "config references GAIA dataset URL" {
  local out="$BATS_TEST_TMPDIR/o"
  bash "$SCRIPT" --level L1 --output-dir "$out" >/dev/null 2>&1
  run grep -c 'gaia-benchmark' "$out/harness-config.yaml"
  [[ "$output" -ge 1 ]]
}

@test "config includes zero_egress sovereignty" {
  local out="$BATS_TEST_TMPDIR/o"
  bash "$SCRIPT" --level L1 --output-dir "$out" >/dev/null 2>&1
  run grep -c 'zero_egress: true' "$out/harness-config.yaml"
  [[ "$output" -ge 1 ]]
}

@test "config includes level in levels list" {
  local out="$BATS_TEST_TMPDIR/o"
  bash "$SCRIPT" --level L2 --output-dir "$out" >/dev/null 2>&1
  run grep -c '^    - L2' "$out/harness-config.yaml"
  [[ "$output" -ge 1 ]]
}

@test "all levels expands to L1+L2+L3" {
  local out="$BATS_TEST_TMPDIR/o"
  bash "$SCRIPT" --level all --output-dir "$out" >/dev/null 2>&1
  run grep -cE '^    - L[123]' "$out/harness-config.yaml"
  [[ "$output" -eq 3 ]]
}

@test "--agent-id propagates to config" {
  local out="$BATS_TEST_TMPDIR/o"
  bash "$SCRIPT" --level L1 --output-dir "$out" --agent-id my-custom-agent >/dev/null 2>&1
  run grep -c 'my-custom-agent' "$out/harness-config.yaml"
  [[ "$output" -ge 1 ]]
}

@test "--n-tasks propagates to config" {
  local out="$BATS_TEST_TMPDIR/o"
  bash "$SCRIPT" --level L1 --output-dir "$out" --n-tasks 25 >/dev/null 2>&1
  run grep -c 'n_tasks_per_level: 25' "$out/harness-config.yaml"
  [[ "$output" -ge 1 ]]
}

@test "results template is valid JSON" {
  local out="$BATS_TEST_TMPDIR/o"
  bash "$SCRIPT" --level L1 --output-dir "$out" >/dev/null 2>&1
  run bash -c 'python3 -c "import json; json.load(open(\"'"$out"'/results-template.json\"))" && echo ok'
  [[ "$output" == *"ok"* ]]
}

@test "prompts-subset.jsonl is valid JSONL" {
  local out="$BATS_TEST_TMPDIR/o"
  bash "$SCRIPT" --level L1 --output-dir "$out" >/dev/null 2>&1
  run bash -c 'python3 -c "
import json
with open(\"'"$out"'/prompts-subset.jsonl\") as f:
    for line in f:
        if line.strip():
            json.loads(line)
print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}

# ── Isolation ────────────────────────────────────────────────────────────

@test "isolation: writes only in --output-dir" {
  local out="$BATS_TEST_TMPDIR/o"
  echo "untouched" > "$BATS_TEST_TMPDIR/sibling.txt"
  bash "$SCRIPT" --level L1 --output-dir "$out" >/dev/null 2>&1
  run cat "$BATS_TEST_TMPDIR/sibling.txt"
  [[ "$output" == "untouched" ]]
}

@test "isolation: output-dir created if missing" {
  local out="$BATS_TEST_TMPDIR/new/nested"
  [[ ! -d "$out" ]]
  run bash "$SCRIPT" --level L1 --output-dir "$out"
  [ "$status" -eq 0 ]
  [[ -d "$out" ]]
}

@test "isolation: exit codes 0 or 2" {
  local out="$BATS_TEST_TMPDIR/o"
  run bash "$SCRIPT" --level L1 --output-dir "$out"
  [[ "$status" -eq 0 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
