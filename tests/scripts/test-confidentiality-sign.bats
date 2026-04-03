#!/usr/bin/env bats
# Tests for confidentiality-sign.sh — cryptographic audit signing
# Ref: pr-signing-protocol.md

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

# ── Structure ──

@test "sign: script is valid bash" {
  bash -n "$SCRIPT"
}

@test "sign: uses set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

# ── Positive cases ──

@test "sign: status runs without crash" {
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
}

@test "sign: sign produces SIGNED output" {
  run bash "$SCRIPT" sign
  [ "$status" -eq 0 ]
  [[ "$output" == *"SIGNED"* ]]
}

@test "sign: secret key created on first sign" {
  bash "$SCRIPT" sign >/dev/null 2>&1
  [ -f "$HOME/.savia/confidentiality-key" ]
}

@test "sign: secret key has 600 permissions" {
  bash "$SCRIPT" sign >/dev/null 2>&1
  local perms
  perms=$(stat -c %a "$HOME/.savia/confidentiality-key" 2>/dev/null || stat -f %Lp "$HOME/.savia/confidentiality-key" 2>/dev/null)
  [ "$perms" = "600" ]
}

# ── Negative cases ──

@test "sign: unknown subcommand shows usage and exits 2" {
  run bash "$SCRIPT" foobar
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "sign: verify requires signature file existence check" {
  grep -q '! -f.*SIG_FILE' "$SCRIPT"
}

# ── Edge cases ──

@test "sign: secret dir created if missing" {
  rm -rf "$HOME/.savia"
  run bash "$SCRIPT" sign
  [ "$status" -eq 0 ]
  [ -d "$HOME/.savia" ]
}

@test "sign: handles empty diff gracefully" {
  run bash "$SCRIPT" sign
  [[ "$output" == *"hash="* ]] || [[ "$output" == *"SIGNED"* ]]
}

# ── Coverage breadth ──

@test "sign: uses sha256sum for hashing" {
  grep -q 'sha256sum' "$SCRIPT"
}

@test "sign: uses openssl HMAC" {
  grep -q 'openssl dgst.*sha256.*hmac' "$SCRIPT"
}

@test "sign: signature format has 4 required fields" {
  grep -q 'diff_hash=' "$SCRIPT"
  grep -q 'timestamp=' "$SCRIPT"
  grep -q 'signature=' "$SCRIPT"
  grep -q 'branch=' "$SCRIPT"
}

@test "sign: excludes self-referencing files from diff" {
  grep -q 'confidentiality-signature' "$SCRIPT"
}

@test "sign: get_diff_hash function exists" {
  grep -q 'get_diff_hash' "$SCRIPT"
}

@test "sign: ensure_secret function exists" {
  grep -q 'ensure_secret' "$SCRIPT"
}

@test "sign: compute_hmac function exists" {
  grep -q 'compute_hmac' "$SCRIPT"
}
