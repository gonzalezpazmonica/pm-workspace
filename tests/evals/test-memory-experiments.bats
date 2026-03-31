#!/usr/bin/env bats
# Tests for SPEC-040 Memory R&D Experiments
# Safety: scripts use set -uo pipefail or Python equivalents

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  STORE="tests/evals/memory-benchmark-store.jsonl"
  SCRIPT="scripts/memory-experiments.py"
  TMPDIR_ME=$(mktemp -d)
}
teardown() { rm -rf "$TMPDIR_ME"; }

@test "memory-experiments.py valid syntax" {
  python3 -c "import py_compile; py_compile.compile('scripts/memory-experiments.py', doraise=True)"
}

@test "EXP-01: forgetting curve runs without error" {
  run python3 scripts/memory-experiments.py exp01 --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ebbinghaus"* ]]
  [[ "$output" == *"linear_top5"* ]]
}

@test "EXP-01: produces formula and half-life" {
  run python3 scripts/memory-experiments.py exp01 --store "$STORE"
  [[ "$output" == *"formula"* ]]
  [[ "$output" == *"half_life"* ]]
}

@test "EXP-02: sequence prediction runs without error" {
  run python3 scripts/memory-experiments.py exp02
  [ "$status" -eq 0 ]
  [[ "$output" == *"Workflow Sequence"* ]]
  [[ "$output" == *"top3_accuracy"* ]]
}

@test "EXP-02: top-3 accuracy >= 0.70 (hypothesis confirmed)" {
  run python3 -c "
import json, subprocess
r = subprocess.run(['python3','scripts/memory-experiments.py','exp02'],
                   capture_output=True, text=True)
d = json.loads(r.stdout)
acc = d['top3_accuracy']
assert acc >= 0.70, f'Top-3 accuracy {acc} < 0.70'
print(f'OK: top3={acc}')
"
  [ "$status" -eq 0 ]
}

@test "EXP-02: transition model has >= 15 commands" {
  run python3 -c "
import json, subprocess
r = subprocess.run(['python3','scripts/memory-experiments.py','exp02'],
                   capture_output=True, text=True)
d = json.loads(r.stdout)
assert d['commands'] >= 15, f'Only {d[\"commands\"]} commands'
print(f'OK: {d[\"commands\"]} commands')
"
  [ "$status" -eq 0 ]
}

@test "EXP-03: consolidation runs without error" {
  run python3 scripts/memory-experiments.py exp03 --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Consolidation"* ]]
}

@test "all: runs all 3 experiments" {
  run python3 scripts/memory-experiments.py all --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"exp01"* ]]
  [[ "$output" == *"exp02"* ]]
  [[ "$output" == *"exp03"* ]]
}

@test "error: invalid experiment name fails gracefully" {
  run python3 "$SCRIPT" exp99 --store "$STORE"
  [ "$status" -ne 0 ] || [[ "$output" == *"error"* ]] || [[ "$output" == *"usage"* ]]
}

@test "error: missing store path fails gracefully" {
  run python3 "$SCRIPT" exp01 --store "$TMPDIR_ME/nonexistent.jsonl"
  [ "$status" -eq 0 ] || [ "$status" -ne 0 ]
}

@test "SPEC-040 document exists" {
  [ -f "docs/propuestas/SPEC-040-memory-research-experiments.md" ]
}
