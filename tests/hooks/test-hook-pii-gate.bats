#!/usr/bin/env bats
# Tests for hook-pii-gate.sh — PII detection pre-commit hook

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/hook-pii-gate.sh"

setup() {
  export TMPDIR_TEST=$(mktemp -d)
  # Create a temp git repo for staging
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

@test "pii-gate: script is valid bash" {
  bash -n "$SCRIPT"
}

@test "pii-gate: disabled by default (no PII_CHECK_ENABLED)" {
  unset PII_CHECK_ENABLED
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "pii-gate: enabled with PII_CHECK_ENABLED=true" {
  export PII_CHECK_ENABLED=true
  # No staged files → clean exit
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No staged"* ]] || [[ "$output" == *"PII"* ]]
}

@test "pii-gate: detects real email addresses" {
  export PII_CHECK_ENABLED=true
  echo "contact: john.doe@realcompany.com" > test.txt
  git add test.txt
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Email"* ]]
}

@test "pii-gate: ignores test/example emails" {
  export PII_CHECK_ENABLED=true
  echo "contact: user@example.com" > test.txt
  git add test.txt
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
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

@test "pii-gate: detects API key patterns" {
  export PII_CHECK_ENABLED=true
  echo "key: ghp_1234567890abcdef1234567890abcdef1234" > test.txt
  git add test.txt
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"API-Key"* ]]
}

@test "pii-gate: skips binary files" {
  export PII_CHECK_ENABLED=true
  echo "data" > test.png
  git add test.png
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

@test "pii-gate: API key regex pattern is defined" {
  # Verify the script checks for AWS/Google/GitHub key patterns
  grep -q 'AKIA' "$SCRIPT"
  grep -q 'AIza' "$SCRIPT"
  grep -q 'ghp_' "$SCRIPT"
}
