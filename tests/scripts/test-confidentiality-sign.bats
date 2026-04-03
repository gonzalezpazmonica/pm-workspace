#!/usr/bin/env bats
# Tests for confidentiality-sign.sh — cryptographic audit signing
# SPEC: pr-signing-protocol.md

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/confidentiality-sign.sh"

setup() {
  export TMPDIR_TEST=$(mktemp -d)
  export ORIG_HOME="$HOME"
  export HOME="$TMPDIR_TEST/home"
  mkdir -p "$HOME/.savia"
}

teardown() {
  export HOME="$ORIG_HOME"
  rm -rf "$TMPDIR_TEST"
}

@test "confidentiality-sign: script is valid bash" {
  bash -n "$SCRIPT"
}

@test "confidentiality-sign: uses set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "confidentiality-sign: unknown subcommand shows usage" {
  run bash "$SCRIPT" foobar
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "confidentiality-sign: status runs without crash" {
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
}

@test "confidentiality-sign: sign produces SIGNED output" {
  run bash "$SCRIPT" sign
  [ "$status" -eq 0 ]
  [[ "$output" == *"SIGNED"* ]]
}

@test "confidentiality-sign: uses sha256sum for diff hashing" {
  grep -q 'sha256sum' "$SCRIPT"
}

@test "confidentiality-sign: uses openssl for HMAC" {
  grep -q 'openssl dgst.*sha256.*hmac' "$SCRIPT"
}

@test "confidentiality-sign: secret key created with 600 perms" {
  bash "$SCRIPT" sign >/dev/null 2>&1
  [ -f "$HOME/.savia/confidentiality-key" ]
  local perms
  perms=$(stat -c %a "$HOME/.savia/confidentiality-key" 2>/dev/null || stat -f %Lp "$HOME/.savia/confidentiality-key" 2>/dev/null)
  [ "$perms" = "600" ]
}

@test "confidentiality-sign: signature file format has required fields" {
  grep -q 'diff_hash=' "$SCRIPT"
  grep -q 'timestamp=' "$SCRIPT"
  grep -q 'signature=' "$SCRIPT"
  grep -q 'branch=' "$SCRIPT"
}

@test "confidentiality-sign: verify checks for signature file" {
  grep -q 'No.*signature\|not.*found\|no.*file' "$SCRIPT" || grep -q '! -f.*SIG_FILE' "$SCRIPT"
}
