#!/usr/bin/env bats
# Tests for scripts/savia-doc.sh — wrapper for `python3 -m structured_doc`.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  cd "$REPO_ROOT"
}

@test "wrapper exists and is executable" {
  [ -x scripts/savia-doc.sh ]
}

@test "wrapper is <= 15 lines (Rule #26)" {
  run wc -l scripts/savia-doc.sh
  [ "$status" -eq 0 ]
  lines=$(echo "$output" | awk '{print $1}')
  [ "$lines" -le 15 ]
}

@test "wrapper list-types prints JSON with spec-md" {
  run bash scripts/savia-doc.sh list-types
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"spec-md"'
}

@test "wrapper lints a clean spec with exit 0" {
  run bash scripts/savia-doc.sh lint spec-md docs/specs/SPEC-AGENT-ARCHITECT.spec.md
  [ "$status" -eq 0 ]
}

@test "wrapper --human flag emits human summary" {
  run bash scripts/savia-doc.sh lint spec-md docs/specs/SPEC-AGENT-ARCHITECT.spec.md --human
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "errors="
}

@test "wrapper validate succeeds on clean spec" {
  run bash scripts/savia-doc.sh validate spec-md docs/specs/SPEC-AGENT-ARCHITECT.spec.md
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"valid": true'
}
