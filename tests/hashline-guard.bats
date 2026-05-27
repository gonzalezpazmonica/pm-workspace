#!/usr/bin/env bats
# tests/hashline-guard.bats — SE-149 hashline stale-file protection
# Ref: docs/rules/domain/hashline-edit-protocol.md
# SPEC-SE-149

GUARD="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/hashline-guard.sh"
EDIT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/hashline-edit.sh"

setup() {
  [[ -x "$GUARD" ]] || skip "hashline-guard.sh missing or not executable"
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  TEST_FILE="$TMP_DIR/test-file.txt"
  printf 'line1\nline2\nline3\nline4\nline5\n' > "$TEST_FILE"
  export TEST_FILE
  export HASHLINE_LOG="$TMP_DIR/hashline-edits.log"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# ── Test 1: anchor generates reproducible hash ────────────────────────────────

@test "anchor: generates reproducible hash for same file and line" {
  local out1 out2 hash1 hash2
  out1=$(bash "$GUARD" anchor "$TEST_FILE" 3)
  out2=$(bash "$GUARD" anchor "$TEST_FILE" 3)
  hash1=$(printf '%s' "$out1" | head -1)
  hash2=$(printf '%s' "$out2" | head -1)
  [[ "$hash1" == "$hash2" ]]
  [[ -n "$hash1" ]]
}

# ── Test 2: check passes for unmodified file ──────────────────────────────────

@test "check: exit 0 for file unchanged since anchor" {
  local out hash anchor_text
  out=$(bash "$GUARD" anchor "$TEST_FILE" 3)
  hash=$(printf '%s' "$out" | head -1)
  anchor_text=$(printf '%s' "$out" | tail -n +2)
  run bash "$GUARD" check "$TEST_FILE" "$anchor_text" "$hash"
  [ "$status" -eq 0 ]
}

# ── Test 3: check fails (exit 1) for stale file ───────────────────────────────
# exit 1 fires when anchor first_line is found but the full block no longer matches

@test "check: exit 1 when anchor block partially changed (first line still present)" {
  local out hash anchor_text
  out=$(bash "$GUARD" anchor "$TEST_FILE" 3)
  hash=$(printf '%s' "$out" | head -1)
  anchor_text=$(printf '%s' "$out" | tail -n +2)

  # Change line3 (center of anchor context): anchor starts with line2 (still present)
  # but full block "line2\nline3\nline4" no longer matches → exit 1
  sed -i 's/^line3$/MODIFIED3/' "$TEST_FILE"

  run bash "$GUARD" check "$TEST_FILE" "$anchor_text" "$hash"
  [ "$status" -eq 1 ]
}

# ── Test 4: check fails (exit 2) for anchor_text not found ───────────────────

@test "check: exit 2 when anchor_text not present in file" {
  local hash="deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678"
  run bash "$GUARD" check "$TEST_FILE" "NONEXISTENT_TEXT_XYZ" "$hash"
  [ "$status" -eq 2 ]
}

# ── Test 5: hashline-edit applies change correctly ────────────────────────────

@test "hashline-edit: applies old_string→new_string replacement" {
  [[ -x "$EDIT" ]] || skip "hashline-edit.sh missing or not executable"
  run bash "$EDIT" "$TEST_FILE" "line3" "REPLACED"
  [ "$status" -eq 0 ]
  grep -q "REPLACED" "$TEST_FILE"
  ! grep -q "^line3$" "$TEST_FILE"
}

# ── Test 6: hashline-edit fails (exit 2) if old_string not in file ────────────

@test "hashline-edit: exit 2 when old_string not found" {
  [[ -x "$EDIT" ]] || skip "hashline-edit.sh missing or not executable"
  run bash "$EDIT" "$TEST_FILE" "THIS_DOES_NOT_EXIST" "anything"
  [ "$status" -eq 2 ]
}

# ── Test 7: anchor handles first line (no N-1) ────────────────────────────────

@test "anchor: handles line 1 boundary (no preceding line)" {
  local out hash
  out=$(bash "$GUARD" anchor "$TEST_FILE" 1)
  hash=$(printf '%s' "$out" | head -1)
  [[ -n "$hash" ]]
}

# ── Test 8: anchor handles last line (no N+1) ────────────────────────────────

@test "anchor: handles last line boundary (no following line)" {
  local total out hash
  total=$(wc -l < "$TEST_FILE")
  out=$(bash "$GUARD" anchor "$TEST_FILE" "$total")
  hash=$(printf '%s' "$out" | head -1)
  [[ -n "$hash" ]]
}

# ── Test 9: hashline-edit logs to HASHLINE_LOG ───────────────────────────────

@test "hashline-edit: logs OK entry to HASHLINE_LOG" {
  [[ -x "$EDIT" ]] || skip "hashline-edit.sh missing or not executable"
  bash "$EDIT" "$TEST_FILE" "line3" "LOGGED"
  [[ -f "$HASHLINE_LOG" ]]
  grep -q "OK" "$HASHLINE_LOG"
  grep -q "$TEST_FILE" "$HASHLINE_LOG"
}

# ── Test 10: check exit 2 when entire first line of anchor is removed ─────────

@test "check: exit 2 when file modified so anchor first line is gone" {
  local out hash anchor_text
  out=$(bash "$GUARD" anchor "$TEST_FILE" 3)
  hash=$(printf '%s' "$out" | head -1)
  anchor_text=$(printf '%s' "$out" | tail -n +2)

  # Remove line2 entirely → anchor first line not findable
  sed -i '/^line2$/d' "$TEST_FILE"

  run bash "$GUARD" check "$TEST_FILE" "$anchor_text" "$hash"
  [ "$status" -eq 2 ]
}

# ── Test 11: safety flags present in script ───────────────────────────────────

@test "safety: hashline-guard.sh has set -uo pipefail" {
  grep -q "set -uo pipefail" "$GUARD"
}

# ── Test 12: invalid command rejects with error ───────────────────────────────

@test "invalid command: rejects unknown subcommand with error" {
  run bash "$GUARD" unknown-subcommand
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"Usage"* ]]
}

# ── Test 13: anchor fails on nonexistent file ─────────────────────────────────

@test "anchor: fails gracefully on nonexistent file" {
  run bash "$GUARD" anchor "/nonexistent/path/file.txt" 1
  [ "$status" -ne 0 ]
}

# ── Test 14: anchor fails with zero or invalid line number ───────────────────

@test "anchor: fails with zero line number (boundary invalid input)" {
  run bash "$GUARD" anchor "$TEST_FILE" "abc"
  [ "$status" -ne 0 ]
}

# ── Test 15: anchor with no arguments is rejected ────────────────────────────

@test "anchor: missing arguments are rejected (no-arg guard)" {
  run bash "$GUARD" anchor
  [ "$status" -ne 0 ]
}

# ── Test 16: check with empty anchor_text is rejected ────────────────────────

@test "check: empty anchor_text returns error exit code" {
  run bash "$GUARD" check "$TEST_FILE" "" "deadbeef"
  [ "$status" -ne 0 ]
}

# ── Test 17: _hash_lines produces 64-char SHA256 hex ─────────────────────────

@test "_hash_lines: anchor hash is 64-character hex (SHA256)" {
  local out hash
  out=$(bash "$GUARD" anchor "$TEST_FILE" 3)
  hash=$(printf '%s' "$out" | head -1)
  [[ ${#hash} -eq 64 ]]
  [[ "$hash" =~ ^[0-9a-f]+$ ]]
}

# ── Test 18: _extract_context returns multi-line context block ───────────────

@test "_extract_context: anchor context includes target line and neighbours" {
  local out anchor_text
  out=$(bash "$GUARD" anchor "$TEST_FILE" 3)
  anchor_text=$(printf '%s' "$out" | tail -n +2)
  # context should contain the target line (line3)
  [[ "$anchor_text" == *"line3"* ]]
  # context should be at least 1 line
  local lc
  lc=$(printf '%s\n' "$anchor_text" | wc -l)
  [ "$lc" -ge 1 ]
}

# ── Test 19: check missing file argument is rejected ─────────────────────────

@test "check: missing file argument is rejected (missing arg)" {
  run bash "$GUARD" check
  [ "$status" -ne 0 ]
}

# ── Test 20: hashline-edit fails gracefully on nonexistent file ───────────────

@test "hashline-edit: fails gracefully on nonexistent file" {
  [[ -x "$EDIT" ]] || skip "hashline-edit.sh missing or not executable"
  run bash "$EDIT" "/nonexistent/path.txt" "old" "new"
  [ "$status" -ne 0 ]
}
