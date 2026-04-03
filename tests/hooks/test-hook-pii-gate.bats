#!/usr/bin/env bats
# Tests for hook-pii-gate.sh — PII detection pre-commit hook
# Ref: pii-sanitization.md, security-check-patterns.md

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/hook-pii-gate.sh"

setup() {
  export TMPDIR_TEST=$(mktemp -d)
  GIT_REPO="$TMPDIR_TEST/repo"
  mkdir -p "$GIT_REPO"
  git -C "$GIT_REPO" init --quiet
  git -C "$GIT_REPO" config user.email "test@test.com"
  git -C "$GIT_REPO" config user.name "Test"
  cd "$GIT_REPO"
}

teardown() {
  cd /
  rm -rf "$TMPDIR_TEST"
}

# ── Structure ──

@test "pii-gate: script is valid bash" {
  bash -n "$SCRIPT"
}

@test "pii-gate: has set safety and error handling" {
  grep -q 'set -uo pipefail\|trap' "$SCRIPT"
}

@test "pii-gate: log_finding function exists" {
  grep -q 'log_finding' "$SCRIPT"
}

@test "pii-gate: should_skip_file function exists" {
  grep -q 'should_skip_file' "$SCRIPT"
}

@test "pii-gate: check_pii function exists" {
  grep -q 'check_pii' "$SCRIPT"
}

# ── Positive cases ──

@test "pii-gate: disabled by default (no PII_CHECK_ENABLED)" {
  unset PII_CHECK_ENABLED
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "pii-gate: clean file passes" {
  export PII_CHECK_ENABLED=true
  echo "This is clean code without any PII" > clean.txt
  git add clean.txt
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No PII"* ]]
}

@test "pii-gate: no staged files exits clean" {
  export PII_CHECK_ENABLED=true
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "pii-gate: ignores test/example emails" {
  export PII_CHECK_ENABLED=true
  echo "contact: user@example.com" > test.txt
  git add test.txt
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Negative cases (detections) ──

@test "pii-gate: detects real email addresses" {
  export PII_CHECK_ENABLED=true
  echo "contact: john.doe@realcompany.com" > test.txt
  git add test.txt
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Email"* ]]
}

@test "pii-gate: detects DNI pattern" {
  export PII_CHECK_ENABLED=true
  echo "DNI: 12345678A" > test.txt
  git add test.txt
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"DNI"* ]]
}

@test "pii-gate: detects private IP" {
  export PII_CHECK_ENABLED=true
  echo "server: 192.168.1.100" > test.txt
  git add test.txt
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Private-IP"* ]]
}

@test "pii-gate: detects GitHub token pattern" {
  export PII_CHECK_ENABLED=true
  echo "key: ghp_1234567890abcdef1234567890abcdef1234" > test.txt
  git add test.txt
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"API-Key"* ]]
}

# ── Edge cases ──

@test "pii-gate: skips binary files" {
  export PII_CHECK_ENABLED=true
  echo "john@realcorp.com" > test.png
  git add test.png
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "pii-gate: skips gitignored files" {
  export PII_CHECK_ENABLED=true
  echo "*.secret" > .gitignore
  echo "john@realcorp.com" > leak.secret
  git add .gitignore
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "pii-gate: multiple findings in same file" {
  export PII_CHECK_ENABLED=true
  printf "email: john@corp.com\nip: 10.0.0.1\n" > multi.txt
  git add multi.txt
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Email"* ]]
  [[ "$output" == *"Private-IP"* ]]
}

@test "pii-gate: empty staged file passes" {
  export PII_CHECK_ENABLED=true
  touch empty.txt
  git add empty.txt
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Coverage breadth ──

@test "pii-gate: API key patterns are defined in script" {
  grep -q 'AKIA' "$SCRIPT"
  grep -q 'AIza' "$SCRIPT"
  grep -q 'ghp_' "$SCRIPT"
}

@test "pii-gate: IBAN detection pattern exists" {
  grep -q 'IBAN\|iban' "$SCRIPT"
}

@test "pii-gate: company form detection exists" {
  grep -q 'S\.L\.\|S\.A\.\|Ltd\|GmbH' "$SCRIPT"
}

@test "pii-gate: findings counter uses file (not subshell var)" {
  # Regression: old version used pipe subshell that never propagated FINDINGS
  grep -q 'FINDINGS_FILE\|mktemp' "$SCRIPT"
}
