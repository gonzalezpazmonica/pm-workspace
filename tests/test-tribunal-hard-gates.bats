#!/usr/bin/env bats
# tests/test-tribunal-hard-gates.bats — SE-227 Slice 1
#
# BATS tests for scripts/tribunal-hard-gates.sh and scripts/tribunal-nonce-gen.sh.
# All gates are deterministic (zero LLM). Tests must pass offline.
#
# Requirements: bats-core, bash, python3 (stdlib), openssl or python3 hashlib
#
# SE-227 — docs/propuestas/SE-227-mech-gov-hard-gates-tribunales.md

HARD_GATES="$BATS_TEST_DIRNAME/../scripts/tribunal-hard-gates.sh"
NONCE_GEN="$BATS_TEST_DIRNAME/../scripts/tribunal-nonce-gen.sh"

# ── Setup ─────────────────────────────────────────────────────────────────────

setup() {
  TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# Helper: short string (10 chars) below MIN_LENGTH
_short_content() { printf 'x%.0s' {1..10}; }  # 10 chars
# Helper: valid content (>50 chars)
_valid_content() { printf 'x%.0s' {1..60}; }  # 60 chars
# Helper: oversized content (>50000 chars)
_huge_content()  { python3 -c "print('x' * 60001)"; }

# ── Test 1: tribunal-hard-gates.sh exists and is executable ──────────────────

@test "hard-gates script exists" {
  [ -f "$HARD_GATES" ]
}

@test "hard-gates script is executable" {
  [ -x "$HARD_GATES" ]
}

# ── Test 2: no_empty_output — missing file ────────────────────────────────────

@test "no_empty_output gate fails with nonexistent input file" {
  run bash "$HARD_GATES" --tribunal recommendation \
    --input-file "$TMP_DIR/does_not_exist.txt"
  [ "$status" -eq 1 ]
  # JSON must contain "passed":false and "no_empty_output"
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['passed'] == False, 'expected passed=false'
assert d['gate'] == 'no_empty_output', f\"expected gate=no_empty_output got {d.get('gate')}\"
"
}

# ── Test 3: format_check — empty file ────────────────────────────────────────

@test "format_check gate fails with empty input file" {
  local f="$TMP_DIR/empty.txt"
  touch "$f"
  run bash "$HARD_GATES" --tribunal recommendation \
    --input-file "$f" --format-check
  [ "$status" -eq 1 ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['passed'] == False, 'expected passed=false'
assert d['gate'] == 'format_check', f\"expected gate=format_check got {d.get('gate')}\"
"
}

# ── Test 4: format_check — valid content (>50 chars) ─────────────────────────

@test "format_check gate passes with content longer than 50 chars" {
  local f="$TMP_DIR/valid.txt"
  _valid_content > "$f"
  run bash "$HARD_GATES" --tribunal recommendation \
    --input-file "$f" --format-check
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['passed'] == True, f\"expected passed=true, got {d}\"
"
}

# ── Test 5: length_range — short input (<50 chars) ───────────────────────────

@test "length_range gate fails with input of 10 chars" {
  local f="$TMP_DIR/short.txt"
  _short_content > "$f"
  run bash "$HARD_GATES" --tribunal truth \
    --input-file "$f"
  [ "$status" -eq 1 ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['passed'] == False, 'expected passed=false'
# gate is either length_range or format_check depending on tribunal type
assert d['gate'] in ('length_range', 'format_check', 'no_empty_output'), f\"unexpected gate: {d.get('gate')}\"
"
}

# ── Test 6: length_range — oversized input (>50000 chars) ────────────────────

@test "length_range gate fails with input larger than 50000 chars" {
  local f="$TMP_DIR/huge.txt"
  _huge_content > "$f"
  run bash "$HARD_GATES" --tribunal truth \
    --input-file "$f" --length-check
  [ "$status" -eq 1 ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['passed'] == False, 'expected passed=false'
assert d['gate'] == 'length_range', f\"expected gate=length_range got {d.get('gate')}\"
"
}

# ── Test 7: spec_syntax — no spec reference passes ───────────────────────────

@test "spec_syntax gate passes when no spec path is referenced" {
  local f="$TMP_DIR/nospec.txt"
  printf 'This draft has no spec path references at all, just plain text content.' > "$f"
  run bash "$HARD_GATES" --tribunal recommendation \
    --input-file "$f"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['passed'] == True, f\"expected passed=true, got {d}\"
"
}

# ── Test 8: e3_nonce_check — nonce absent in judge output ────────────────────

@test "e3_nonce_check gate fails when nonce is not in judge output" {
  local f="$TMP_DIR/no_nonce.txt"
  printf 'x%.0s' {1..60} > "$f"
  echo "Judge verdict: PASS. Some detailed reasoning here." >> "$f"
  run bash "$HARD_GATES" --tribunal recommendation \
    --input-file "$f" \
    --nonce "EXPECTEDNONCE_abc123xyz789_notpresent"
  [ "$status" -eq 1 ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['passed'] == False, 'expected passed=false'
assert d['gate'] == 'e3_nonce_check', f\"expected gate=e3_nonce_check got {d.get('gate')}\"
"
}

# ── Test 9: e3_nonce_check — nonce present in judge output ───────────────────

@test "e3_nonce_check gate passes when nonce is present in judge output" {
  local f="$TMP_DIR/with_nonce.txt"
  local test_nonce="TESTNONCE_se227_1234567890abcdef"
  printf 'x%.0s' {1..60} > "$f"
  printf '\nNonce commit: %s\nJudge verdict: PASS.\n' "$test_nonce" >> "$f"
  run bash "$HARD_GATES" --tribunal recommendation \
    --input-file "$f" \
    --nonce "$test_nonce"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['passed'] == True, f\"expected passed=true, got {d}\"
"
}

# ── Test 10: tribunal-nonce-gen.sh --self-test passes ────────────────────────

@test "nonce-gen --self-test passes" {
  run bash "$NONCE_GEN" --self-test
  [ "$status" -eq 0 ]
}

# ── Test 11: nonce-gen generates 64-char lowercase hex nonce ─────────────────

@test "nonce-gen produces 64-char hex string" {
  run bash "$NONCE_GEN"
  [ "$status" -eq 0 ]
  # Strip trailing newline and check format
  local nonce="${output%$'\n'}"
  [[ "${#nonce}" -eq 64 ]]
  [[ "$nonce" =~ ^[0-9a-f]{64}$ ]]
}

# ── Test 12: nonce-gen --verify detects presence ─────────────────────────────

@test "nonce-gen --verify returns 0 when nonce is in file" {
  local nonce
  nonce="$(bash "$NONCE_GEN")"
  nonce="${nonce%$'\n'}"
  local f="$TMP_DIR/judge_output.txt"
  printf 'NONCE_COMMIT: %s\nVerdict: PASS.\n' "$nonce" > "$f"
  run bash "$NONCE_GEN" --verify "$nonce" "$f"
  [ "$status" -eq 0 ]
}

# ── Test 13: gates_run count is accurate in output JSON ──────────────────────

@test "output JSON reports accurate gates_run count" {
  local f="$TMP_DIR/valid2.txt"
  _valid_content > "$f"
  local test_nonce="GATECOUNT_NONCE_abcdef1234567890"
  printf '\n%s\n' "$test_nonce" >> "$f"
  run bash "$HARD_GATES" --tribunal recommendation \
    --input-file "$f" \
    --nonce "$test_nonce"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['passed'] == True, f\"expected passed=true, got {d}\"
# gates_run should be >= 3: no_empty_output + format_check + spec_syntax + nonce
assert d['gates_run'] >= 3, f\"expected >=3 gates, got {d.get('gates_run')}\"
"
}
