#!/usr/bin/env bats
# Tests for SPEC-055 Test Auditor System

AUDITOR="scripts/test-auditor.sh"
ENGINE="scripts/test-auditor-engine.py"
COVERAGE="scripts/test-coverage-checker.sh"
GATE="scripts/ci-test-quality-gate.sh"

setup() {
  TMPDIR_AUD=$(mktemp -d)
  # Create minimal test file without inline @test (avoid BATS heredoc parsing)
  printf '#!/usr/bin/env bats\n' > "$TMPDIR_AUD/test-minimal.bats"
  printf '%s "%s" { [ -f "scripts/some-script.sh" ]; }\n' '@test' 'script exists' >> "$TMPDIR_AUD/test-minimal.bats"
  chmod +x "$TMPDIR_AUD/test-minimal.bats"
}
teardown() { rm -rf "$TMPDIR_AUD"; }

@test "test-auditor.sh exists and is executable" {
  [ -f "$AUDITOR" ] && [ -x "$AUDITOR" ]
}

@test "test-auditor-engine.py exists" {
  [ -f "$ENGINE" ]
}

@test "test-auditor.sh has set -uo pipefail" {
  head -15 "$AUDITOR" | grep -q "set -uo pipefail"
}

@test "scores a known-good test >= 80" {
  run python3 "$ENGINE" "tests/evals/test-trace-pattern-extractor.bats" "."
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['total']>=80, f'Expected >=80, got {d[\"total\"]}'
assert d['certified']==True
"
}

@test "scores a minimal test < 80" {
  run python3 "$ENGINE" "$TMPDIR_AUD/test-minimal.bats" "."
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['total']<80, f'Expected <80, got {d[\"total\"]}'
assert d['certified']==False
"
}

@test "produces valid JSON with all 9 criteria" {
  run python3 "$ENGINE" "tests/evals/test-trace-pattern-extractor.bats" "."
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
expected=['exists_executable','safety_verification','positive_cases',
  'negative_cases','edge_cases','isolation','coverage_breadth',
  'spec_reference','assertion_quality']
for k in expected: assert k in d['criteria'], f'Missing: {k}'
"
}

@test "hash format is 8 hex characters" {
  run python3 "$ENGINE" "tests/evals/test-trace-pattern-extractor.bats" "."
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys,re; d=json.load(sys.stdin)
assert re.match(r'^[0-9a-f]{8}$', d['hash']), f'Bad hash: {d[\"hash\"]}'
"
}

@test "hash is deterministic for same input" {
  H1=$(python3 "$ENGINE" "tests/evals/test-trace-pattern-extractor.bats" "." | python3 -c "import json,sys; print(json.load(sys.stdin)['hash'])")
  H2=$(python3 "$ENGINE" "tests/evals/test-trace-pattern-extractor.bats" "." | python3 -c "import json,sys; print(json.load(sys.stdin)['hash'])")
  [ "$H1" = "$H2" ]
}

@test "--all mode processes multiple test files" {
  run bash "$AUDITOR" --all --json
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['total_files']>=1, f'Expected >=1 files'
assert 'results' in d
"
}

@test "handles missing file gracefully" {
  run python3 "$ENGINE" "/nonexistent/test.bats" "."
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['total']<20, 'Missing file should score very low'
"
}

@test "test-coverage-checker.sh exists and produces JSON" {
  [ -f "$COVERAGE" ] && [ -x "$COVERAGE" ]
  run bash "$COVERAGE" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert 'mandatory_total' in d and 'coverage_percent' in d
"
}

@test "ci-test-quality-gate.sh exists and is executable" {
  [ -f "$GATE" ] && [ -x "$GATE" ]
}

@test "engine detects target script from SCRIPT= pattern" {
  run python3 "$ENGINE" "tests/evals/test-trace-pattern-extractor.bats" "."
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['target'] is not None and 'trace-pattern-extractor' in d['target']
"
}

@test "SPEC-055 document exists" {
  [ -f "docs/propuestas/SPEC-055-test-auditor.md" ]
}
