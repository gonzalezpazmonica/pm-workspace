#!/usr/bin/env bats
# Tests for SPEC-047 Requirement Pushback Pass (Phase 1)

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  SCRIPT="scripts/requirement-pushback.sh"
  export SAMPLE_SPEC="/tmp/test-spec-pushback.md"
  cat > "$SAMPLE_SPEC" << 'EOF'
# SPEC-099: Widget Service

## Problem

All users must have access to the dashboard at all times.
The system should be fast and scalable.

## Solution

A 5-component pipeline that orchestrates widget creation:
- Component A: ingestion
- Component B: validation
- Component C: transformation
- Component D: enrichment
- Component E: storage
- Component F: notification

The system must never fail under load.
Configuration is flexible and intuitive.

## Phase 2 (future)

Eventually we will add real-time streaming.

## Phase 3

Later we will add ML-based recommendations.
EOF
}

teardown() {
  rm -f "$SAMPLE_SPEC" /tmp/test-empty-pushback.md
}

@test "script exists" {
  [ -f "$SCRIPT" ]
}

@test "script is executable" {
  [ -x "$SCRIPT" ]
}

@test "script uses set -uo pipefail" {
  head -10 "$SCRIPT" | grep -q 'set -uo pipefail'
}

@test "handles missing file argument" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"error"* ]]
}

@test "handles nonexistent file" {
  run bash "$SCRIPT" /tmp/no-such-file-pushback-xyz.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"File not found"* ]]
}

@test "handles empty file with valid JSON" {
  touch /tmp/test-empty-pushback.md
  run bash "$SCRIPT" /tmp/test-empty-pushback.md
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['summary']['total_questions'] == 0
assert d['questions'] == []
"
}

@test "produces valid JSON output for sample spec" {
  run bash "$SCRIPT" "$SAMPLE_SPEC"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'spec_file' in d
assert 'timestamp' in d
assert 'questions' in d
assert 'summary' in d
assert isinstance(d['questions'], list)
assert isinstance(d['summary']['total_questions'], int)
assert isinstance(d['summary']['by_type'], dict)
"
}

@test "generates questions for sample spec with assumptions" {
  run bash "$SCRIPT" "$SAMPLE_SPEC"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
types = {q['type'] for q in d['questions']}
assert 'assumption' in types, f'Expected assumption in {types}'
assert 'ambiguity' in types, f'Expected ambiguity in {types}'
assert d['summary']['total_questions'] >= 3, f'Expected >=3 questions, got {d[\"summary\"][\"total_questions\"]}'
"
}

@test "edge: boundary spec with no phases still produces valid output" {
  echo "# Simple Spec\n\nJust one requirement." > "$SAMPLE_SPEC"
  run bash "$SCRIPT" "$SAMPLE_SPEC"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "SPEC-047 proposal document exists" {
  [ -f "docs/propuestas/SPEC-047-requirement-pushback.md" ]
}
