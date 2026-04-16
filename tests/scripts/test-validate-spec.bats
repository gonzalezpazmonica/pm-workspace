#!/usr/bin/env bats
# Tests for validate-spec.sh (Era 169 — Spec Schema Validation)
# Ref: docs/rules/domain/dev-session-protocol.md

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)}"

setup() {
  TMPDIR=$(mktemp -d)
  SCRIPT="$REPO_ROOT/scripts/validate-spec.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "validate-spec.sh has safety flags" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "no args returns exit 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "nonexistent file returns exit 2" {
  run bash "$SCRIPT" "/tmp/nope.md"
  [ "$status" -eq 2 ]
}

@test "valid spec passes" {
  cat > "$TMPDIR/good.md" << 'SPEC'
# SPEC-999: Test Spec

**Status**: Draft | **Date**: 2026-04-01

## Problem

Something is broken.

## Solution

Fix it by doing X.

## Files

| File | Action |
|------|--------|
| foo.sh | CREATE |

## Acceptance Criteria

- It works
- Tests pass

## Risks

None significant.
SPEC
  run bash "$SCRIPT" "$TMPDIR/good.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "spec missing Problem section fails" {
  cat > "$TMPDIR/bad.md" << 'SPEC'
# SPEC-998: No Problem

**Status**: Draft

## Solution

Just do it.
SPEC
  run bash "$SCRIPT" "$TMPDIR/bad.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing ## Problem"* ]]
}

@test "spec missing Solution section fails" {
  cat > "$TMPDIR/bad2.md" << 'SPEC'
# SPEC-997: No Solution

**Status**: Draft

## Problem

Something is wrong.
SPEC
  run bash "$SCRIPT" "$TMPDIR/bad2.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing ## Solution"* ]]
}

@test "spec over 150 lines fails" {
  {
    echo "# SPEC-996: Too Long"
    echo "**Status**: Draft"
    echo "## Problem"
    echo "Something."
    echo "## Solution"
    echo "Fix."
    for i in $(seq 1 150); do echo "padding line $i"; done
  } > "$TMPDIR/long.md"
  run bash "$SCRIPT" "$TMPDIR/long.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"exceeds 150"* ]]
}

@test "strict mode requires acceptance criteria" {
  cat > "$TMPDIR/noac.md" << 'SPEC'
# SPEC-995: No AC

**Status**: Draft

## Problem

Something.

## Solution

Fix it.
SPEC
  run bash "$SCRIPT" "$TMPDIR/noac.md" --strict
  [ "$status" -eq 1 ]
  [[ "$output" == *"acceptance criteria"* ]]
}

@test "real spec SPEC-067 passes validation" {
  run bash "$SCRIPT" "$REPO_ROOT/docs/propuestas/SPEC-067-claudemd-diet.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}
