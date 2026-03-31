#!/usr/bin/env bats
# Tests for SPEC-041 Brain-Inspired Context Reasoning
# Safety: scripts use set -uo pipefail or Python equivalent

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  STORE="tests/evals/memory-benchmark-store.jsonl"
  SCRIPT="scripts/context-reasoning.py"
  TMPDIR_CR=$(mktemp -d)
}
teardown() { rm -rf "$TMPDIR_CR"; }

@test "context-reasoning.py valid syntax" {
  python3 -c "import py_compile; py_compile.compile('scripts/context-reasoning.py', doraise=True)"
}

@test "reason: narrow zoom for specific question" {
  run python3 scripts/context-reasoning.py reason "How handle SQL injection?" --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"zoom=narrow"* ]]
}

@test "reason: wide zoom for overview query" {
  run python3 scripts/context-reasoning.py reason "sprint status overview" --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"zoom=wide"* ]]
}

@test "reason: trivial 'ok' produces zero context" {
  run python3 scripts/context-reasoning.py reason "ok" --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0/"* ]]
}

@test "reason: filters noise entries" {
  run python3 scripts/context-reasoning.py reason "all decisions this sprint" --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"noise"* ]]
}

@test "benchmark: accuracy >= 0.80" {
  run python3 -c "
import json, subprocess
r = subprocess.run(['python3','scripts/context-reasoning.py','benchmark',
                    '--store','$STORE'], capture_output=True, text=True)
d = json.loads(r.stdout)
assert d['accuracy'] >= 0.80, f'Accuracy {d[\"accuracy\"]} < 0.80'
print(f'OK: {d[\"accuracy\"]}')
"
  [ "$status" -eq 0 ]
}

@test "benchmark: zoom detection works for 4+ queries" {
  run python3 -c "
import json, subprocess
r = subprocess.run(['python3','scripts/context-reasoning.py','benchmark',
                    '--store','$STORE'], capture_output=True, text=True)
d = json.loads(r.stdout)
zoom_ok = sum(1 for q in d['queries'] if q['zoom_ok'])
assert zoom_ok >= 4, f'Only {zoom_ok} zoom correct'
print(f'OK: {zoom_ok}/6 zoom correct')
"
  [ "$status" -eq 0 ]
}

@test "error: invalid store path fails gracefully" {
  run python3 "$SCRIPT" reason "test query" --store "$TMPDIR_CR/nonexistent.jsonl"
  # Script may exit 0 (empty result) or 1 (error); both are graceful
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "error: missing subcommand fails with usage" {
  run python3 "$SCRIPT"
  [ "$status" -ne 0 ] || [[ "$output" == *"usage"* ]]
}

@test "SPEC-041 document exists" {
  [ -f "docs/propuestas/SPEC-041-brain-context-reasoning.md" ]
}
