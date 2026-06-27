#!/usr/bin/env bats
# tests/test-se228-s2-maker-checker.bats — SE-228 Slice 2: Maker/Checker split protocol
# Ref: docs/rules/domain/maker-checker-protocol.md
# Ref: scripts/loop-verify.sh
# Spec: docs/propuestas/SE-228-loop-engineering-patterns.md (AC-06..AC-10)

PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
PROTOCOL="$PROJECT_ROOT/docs/rules/domain/maker-checker-protocol.md"
SCRIPT="$PROJECT_ROOT/scripts/loop-verify.sh"

setup() {
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# ── Test 1: maker-checker-protocol.md exists ─────────────────────────────────

@test "maker-checker-protocol.md exists in docs/rules/domain/" {
  [[ -f "$PROTOCOL" ]]
}

# ── Test 2: loop-verify.sh exists and is executable ──────────────────────────

@test "loop-verify.sh exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

# ── Test 3: loop-verify.sh --help shows usage ────────────────────────────────

@test "loop-verify.sh --help shows usage" {
  run bash "$SCRIPT" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]]
}

# ── Test 4: loop-verify.sh without args exits 2 ──────────────────────────────

@test "loop-verify.sh without args exits 2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
}

# ── Test 5: loop-verify.sh --worktree . --skill overnight-sprint --dry-run exits 0 ──

@test "loop-verify.sh --worktree . --skill overnight-sprint --dry-run exits 0" {
  run bash "$SCRIPT" --worktree . --skill overnight-sprint --dry-run
  [[ "$status" -eq 0 ]]
}

# ── Test 6: dry-run output contains "REJECT" ─────────────────────────────────

@test "loop-verify.sh --dry-run generates prompt with REJECT" {
  run bash "$SCRIPT" --worktree . --skill overnight-sprint --dry-run
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"REJECT"* ]]
}

# ── Test 7: dry-run output mentions scope minimo ─────────────────────────────

@test "loop-verify.sh --dry-run mentions scope minimo" {
  run bash "$SCRIPT" --worktree . --skill overnight-sprint --dry-run
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -qi "scope m"
}

# ── Test 8: maker-checker-protocol.md mentions "default REJECT" ──────────────

@test "maker-checker-protocol.md mentions default REJECT" {
  run grep -i "default reject" "$PROTOCOL"
  [[ "$status" -eq 0 ]]
}

# ── Test 9: maker-checker-protocol.md has numbered invariants ────────────────

@test "maker-checker-protocol.md has section with numbered invariants" {
  run grep -E "^[0-9]+\." "$PROTOCOL"
  [[ "$status" -eq 0 ]]
  count=$(grep -cE "^[0-9]+\." "$PROTOCOL")
  [[ "$count" -ge 5 ]]
}

# ── Test 10: loop-verify.sh uses set -uo pipefail ────────────────────────────

@test "loop-verify.sh uses set -uo pipefail" {
  run grep "set -uo pipefail" "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

# ── Test 11: missing --worktree exits 2 (no arg boundary) ────────────────────

@test "loop-verify.sh --skill overnight-sprint without --worktree exits 2" {
  run bash "$SCRIPT" --skill overnight-sprint
  [[ "$status" -eq 2 ]]
}

# ── Test 12: empty --worktree value exits 2 (empty boundary) ─────────────────

@test "loop-verify.sh --worktree with empty value exits 2" {
  run bash "$SCRIPT" --worktree "" --skill overnight-sprint
  [[ "$status" -eq 2 ]]
}

# ── Test 13: nonexistent/unknown flag exits 2 ────────────────────────────────

@test "loop-verify.sh with nonexistent unknown flag exits 2" {
  run bash "$SCRIPT" --unknown-flag
  [[ "$status" -eq 2 ]]
}

# ── Test 14: dry-run with tmpdir worktree uses worktree path in output ────────

@test "loop-verify.sh --dry-run includes worktree path in output" {
  run bash "$SCRIPT" --worktree "$TMP_DIR" --skill test-skill --dry-run
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"$TMP_DIR"* ]]
}

# ── Test 15: dry-run with --spec includes spec path in output ────────────────

@test "loop-verify.sh --dry-run with --spec includes spec reference in output" {
  SPEC_PATH="$PROJECT_ROOT/docs/propuestas/SE-228-loop-engineering-patterns.md"
  run bash "$SCRIPT" --worktree . --skill overnight-sprint \
    --spec "$SPEC_PATH" --dry-run
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"SE-228"* ]]
}

# ── Test 16: autonomous-safety.md now references maker-checker-protocol ───────

@test "autonomous-safety.md references maker-checker-protocol.md" {
  SAFETY="$PROJECT_ROOT/docs/rules/domain/autonomous-safety.md"
  run grep -i "maker.checker" "$SAFETY"
  [[ "$status" -eq 0 ]]
}
