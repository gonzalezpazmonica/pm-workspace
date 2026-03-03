#!/bin/bash
# test-savia-confidentiality.sh — E2E encrypted messaging confidentiality
# Verifies: encryption/decryption, idempotency, key-based access control

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0; TOTAL=0
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

assert() {
  TOTAL=$((TOTAL + 1))
  if eval "$2" >/dev/null 2>&1; then PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1${NC}"; fi
}

assert_not() {
  TOTAL=$((TOTAL + 1))
  if ! eval "$2" >/dev/null 2>&1; then PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1${NC}"; fi
}

# ── Setup ─────────────────────────────────────────────────────────
TMPDIR_BASE=$(mktemp -d)
ORIG_HOME="$HOME"
cleanup() { export HOME="$ORIG_HOME"; rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

echo "━━━ Test: Confidentiality — E2E Encryption ━━━"

# Setup alice, bob, carol with isolated HOMEs and keys
for user in alice bob carol; do
  export HOME="$TMPDIR_BASE/home-$user"
  mkdir -p "$HOME/.pm-workspace/savia-keys"
  bash "$SCRIPTS_DIR/savia-crypto.sh" keygen 2>/dev/null
done

SECRET_MSG="El contrato es por 2.5 millones EUR y vence el 15 de abril"

echo ""
echo -e "${BLUE}── Encryption Basics ──${NC}"

# Test 1: Encrypt and verify no plaintext visible
export HOME="$TMPDIR_BASE/home-alice"
BOB_PUBKEY="$TMPDIR_BASE/home-bob/.pm-workspace/savia-keys/public.pem"
ENCRYPTED=$(bash "$SCRIPTS_DIR/savia-crypto.sh" encrypt "$BOB_PUBKEY" "$SECRET_MSG" 2>/dev/null)

assert "Encryption succeeds" "[ -n '$ENCRYPTED' ]"
assert "Encrypted contains separator :::" "echo '$ENCRYPTED' | grep -q ':::'"
assert_not "Plaintext NOT visible in ciphertext" "echo '$ENCRYPTED' | grep -qi 'contrato'"
assert_not "Amount NOT visible in ciphertext" "echo '$ENCRYPTED' | grep -qi '2.5 millones'"

echo ""
echo -e "${BLUE}── Recipient Decryption ──${NC}"

# Test 2: Bob can decrypt with his private key
export HOME="$TMPDIR_BASE/home-bob"
DECRYPTED=$(bash "$SCRIPTS_DIR/savia-crypto.sh" decrypt "$ENCRYPTED" 2>/dev/null)

assert "Bob decrypts successfully" "[ -n '$DECRYPTED' ]"
assert "Decrypted contains contract term" "echo '$DECRYPTED' | grep -q 'contrato'"
assert "Decrypted contains full message" "[ '$DECRYPTED' = '$SECRET_MSG' ]"

echo ""
echo -e "${BLUE}── Non-Recipient Rejection ──${NC}"

# Test 3: Carol cannot decrypt (different private key)
export HOME="$TMPDIR_BASE/home-carol"
CAROL_DECRYPT=$(bash "$SCRIPTS_DIR/savia-crypto.sh" decrypt "$ENCRYPTED" 2>/dev/null || echo "FAILED")

assert_not "Carol decryption fails" "[ '$CAROL_DECRYPT' = '$SECRET_MSG' ]"
assert "Carol gets FAILED or error" "echo '$CAROL_DECRYPT' | grep -q 'FAILED'"

echo ""
echo -e "${BLUE}── Idempotency ──${NC}"

# Test 4: Same plaintext encrypts differently (random AES key)
export HOME="$TMPDIR_BASE/home-alice"
ENC1=$(bash "$SCRIPTS_DIR/savia-crypto.sh" encrypt "$BOB_PUBKEY" "Same message" 2>/dev/null)
ENC2=$(bash "$SCRIPTS_DIR/savia-crypto.sh" encrypt "$BOB_PUBKEY" "Same message" 2>/dev/null)

assert "Two encryptions are different" "[ '$ENC1' != '$ENC2' ]"

# Test 5: Both ciphertexts decrypt to same plaintext
export HOME="$TMPDIR_BASE/home-bob"
DEC1=$(bash "$SCRIPTS_DIR/savia-crypto.sh" decrypt "$ENC1" 2>/dev/null)
DEC2=$(bash "$SCRIPTS_DIR/savia-crypto.sh" decrypt "$ENC2" 2>/dev/null)

assert "Both decryptions match" "[ '$DEC1' = '$DEC2' ]"
assert "Decrypted message correct" "[ '$DEC1' = 'Same message' ]"

echo ""
echo "━━━ Results: $PASS/$TOTAL passed, $FAIL failed ━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
