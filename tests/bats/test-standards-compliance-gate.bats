#!/usr/bin/env bats
# tests/bats/test-standards-compliance-gate.bats — SE-311 S2: compuerta de estandares

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/standards-compliance-gate.sh"
  TESTDIR=$(mktemp -d)
  export SLDC_GATE_ROOT="$TESTDIR"
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "S2: file-size FAIL con fichero >150 lineas" {
  mkdir -p "$TESTDIR/.opencode/agents"
  python3 -c "print('\n'.join(['# line']*160))" > "$TESTDIR/.opencode/agents/big.md"
  run bash "$SCRIPT" --check file-size
  [[ "$output" == *FAIL* ]]
  [ "$status" -eq 1 ]
}

@test "S2: file-size PASS sin ficheros grandes" {
  mkdir -p "$TESTDIR/.opencode/agents"
  python3 -c "print('\n'.join(['# line']*50))" > "$TESTDIR/.opencode/agents/small.md"
  run bash "$SCRIPT" --check file-size
  [[ "$output" == *PASS* ]]
  [ "$status" -eq 0 ]
}

@test "S2: --check con nombre invalido sale con error (exit 2)" {
  run bash "$SCRIPT" --check no-existe
  [ "$status" -eq 2 ]
}

@test "S2: --json emite JSON con verdict y checks" {
  run bash "$SCRIPT" --json
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['verdict'] in ('PASS', 'FAIL')
assert isinstance(d['checks'], dict)
assert isinstance(d['details'], dict)
assert 'file-size' in d['checks']
"
}

@test "S2: --report genera fichero con secciones" {
  run bash "$SCRIPT" --report "$TESTDIR/report.md"
  [ -f "$TESTDIR/report.md" ]
  grep -q "Standards Compliance Gate" "$TESTDIR/report.md"
  grep -q "VERDICT" "$TESTDIR/report.md"
}

@test "S2: el set de checks incluye los 6 esperados" {
  run bash "$SCRIPT" --json
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for c in ['file-size','skill-audit','agent-schema','drift','rules','confid']:
    assert c in d['checks'], f'falta {c}'
"
}

@test "S2: regla de exencion cross-frontend-coverage.md" {
  mkdir -p "$TESTDIR/docs/rules/domain"
  python3 -c "print('\n'.join(['# x']*200))" > "$TESTDIR/docs/rules/domain/cross-frontend-coverage.md"
  run bash "$SCRIPT" --check file-size
  [[ "$output" == *PASS* ]]
}
