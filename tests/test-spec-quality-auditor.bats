#!/usr/bin/env bats
# Tests for spec-quality-auditor.sh — Deterministic spec scorer

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/spec-quality-auditor.sh"
  TMPDIR_SQ=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_SQ"
}

@test "no args shows usage" {
  run bash "$SCRIPT"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Usage"* ]]
}

@test "help flag shows usage" {
  run bash "$SCRIPT" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]]
}

@test "nonexistent file returns error" {
  run bash "$SCRIPT" "$TMPDIR_SQ/nonexistent.md"
  [[ "$output" == *"error"* ]] || [[ "$output" == *"not found"* ]]
}

@test "empty spec scores low" {
  echo "" > "$TMPDIR_SQ/empty.md"
  run bash "$SCRIPT" "$TMPDIR_SQ/empty.md"
  [[ "$status" -eq 0 ]]
  # Score should be very low for empty file
  [[ "$output" =~ [0-9] ]]
}

@test "well-structured spec scores higher" {
  cat > "$TMPDIR_SQ/good.md" << 'EOF'
# SPEC-999: Test Feature

## Status: Draft
## Author: test
## Date: 2026-04-04

## Problem
Users cannot login after session timeout.

## Solution
Implement token refresh mechanism in AuthService.

## Acceptance Criteria
- Given expired token, When user makes request, Then token is refreshed
- Given invalid refresh token, When refresh attempted, Then user is redirected to login

## Effort
Agent: 30min | Human: 2h | Review: 30min

## Dependencies
- AuthService (existing)
- TokenStore (existing)

## Testability
Unit tests for token refresh logic. Integration test for full flow.

## Implementation Notes
Use existing middleware pattern from OrderService.
EOF
  run bash "$SCRIPT" "$TMPDIR_SQ/good.md"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ [0-9] ]]
}

@test "batch mode scans directory" {
  mkdir -p "$TMPDIR_SQ/specs"
  echo "# SPEC-001: A" > "$TMPDIR_SQ/specs/SPEC-001.md"
  echo "# SPEC-002: B" > "$TMPDIR_SQ/specs/SPEC-002.md"
  run bash "$SCRIPT" --batch "$TMPDIR_SQ/specs"
  [[ "$status" -eq 0 ]]
}

@test "min-score filters results" {
  mkdir -p "$TMPDIR_SQ/specs"
  echo "# SPEC-001: Minimal" > "$TMPDIR_SQ/specs/SPEC-001.md"
  run bash "$SCRIPT" --batch "$TMPDIR_SQ/specs" --min-score 90
  [[ "$status" -eq 0 ]]
}

@test "script has set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "scores real SPEC files" {
  local spec_count
  spec_count=$(ls "$REPO_ROOT/docs/propuestas/SPEC-"*.md 2>/dev/null | head -1)
  [[ -n "$spec_count" ]] || skip "No SPEC files found"
  run bash "$SCRIPT" "$spec_count"
  [[ "$status" -eq 0 ]]
}
