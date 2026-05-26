#!/usr/bin/env bats
# tests/hashline-guard.bats — SE-149 hashline stale-file protection
# Ref: docs/rules/domain/hashline-edit-protocol.md

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
