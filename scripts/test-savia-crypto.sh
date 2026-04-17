#!/bin/bash
# test-savia-crypto.sh — Tests for RSA+AES encryption
# Uso: bash scripts/test-savia-crypto.sh

set -euo pipefail

# ── Test harness ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0; TOTAL=0
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

assert_ok() {
  local msg="$1"
  TOTAL=$((TOTAL + 1))
  if [ $? -eq 0 ]; then
    PASS=$((PASS + 1)); echo -e "${GREEN}✅ $msg${NC}"
  else
    FAIL=$((FAIL + 1)); echo -e "${RED}❌ $msg${NC}"
  fi
}

# ── Setup ─────────────────────────────────────────────────────────
TMPDIR_BASE=$(mktemp -d)
ORIG_HOME="$HOME"
export HOME="$TMPDIR_BASE"
KEYS_DIR="$HOME/.pm-workspace/savia-keys"

cleanup() {
  export HOME="$ORIG_HOME"
  rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

echo "━━━ Test: Savia Crypto ━━━"

# ── Test 1-3: Keygen creates RSA keypair ────────────────────────────
bash "$SCRIPTS_DIR/savia-crypto.sh" keygen 2>/dev/null
assert_ok "Keygen succeeded"

TOTAL=$((TOTAL + 1))
if [ -f "$KEYS_DIR/private.pem" ]; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Private key created${NC}"
else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Private key not found${NC}"; fi

TOTAL=$((TOTAL + 1))
if [ -f "$KEYS_DIR/public.pem" ]; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Public key created${NC}"
else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Public key not found${NC}"; fi

# ── Test 4: Private key permissions are 600 ─────────────────────────
TOTAL=$((TOTAL + 1))
PERMS=$(stat -c '%a' "$KEYS_DIR/private.pem" 2>/dev/null || stat -f '%A' "$KEYS_DIR/private.pem" 2>/dev/null)
if [ "$PERMS" = "600" ]; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Private key permissions 600${NC}"
else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Private key permissions: $PERMS${NC}"; fi

# ── Test 5-7: Encrypt/decrypt round-trip ────────────────────────────
PLAINTEXT="Hello, this is a secret message!"
ENCRYPTED=$(bash "$SCRIPTS_DIR/savia-crypto.sh" encrypt "$KEYS_DIR/public.pem" "$PLAINTEXT" 2>/dev/null)
[ -n "$ENCRYPTED" ]
assert_ok "Encryption succeeded"

TOTAL=$((TOTAL + 1))
if echo "$ENCRYPTED" | grep -q ':::'; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Encrypted format has ::: separator${NC}"
else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Encrypted format invalid${NC}"; fi

DECRYPTED=$(bash "$SCRIPTS_DIR/savia-crypto.sh" decrypt "$ENCRYPTED" 2>/dev/null)
[ "$DECRYPTED" = "$PLAINTEXT" ]
assert_ok "Decryption succeeded"

TOTAL=$((TOTAL + 1))
if [ "$DECRYPTED" = "$PLAINTEXT" ]; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Round-trip: plaintext matches${NC}"
else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Round-trip failed${NC}"; fi

# ── Test 8: Wrong key rejection ─────────────────────────────────────
BOB_KEYS="$TMPDIR_BASE/bob-keys"
mkdir -p "$BOB_KEYS"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 \
  -out "$BOB_KEYS/private.pem" 2>/dev/null
openssl rsa -in "$BOB_KEYS/private.pem" -pubout \
  -out "$BOB_KEYS/public.pem" 2>/dev/null

ENCRYPTED_FOR_ALICE=$(bash "$SCRIPTS_DIR/savia-crypto.sh" encrypt "$KEYS_DIR/public.pem" "Secret" 2>/dev/null)

mv "$KEYS_DIR/private.pem" "$KEYS_DIR/private.pem.bak"
cp "$BOB_KEYS/private.pem" "$KEYS_DIR/private.pem"

TOTAL=$((TOTAL + 1))
if bash "$SCRIPTS_DIR/savia-crypto.sh" decrypt "$ENCRYPTED_FOR_ALICE" 2>/dev/null; then
  FAIL=$((FAIL + 1)); echo -e "${RED}❌ Should fail with wrong key${NC}"
else
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Correctly rejected wrong key${NC}"
fi

mv "$KEYS_DIR/private.pem.bak" "$KEYS_DIR/private.pem"

# ── Test 9-10: Idempotency and determinism ───────────────────────────
ENC1=$(bash "$SCRIPTS_DIR/savia-crypto.sh" encrypt "$KEYS_DIR/public.pem" "Same text" 2>/dev/null)
ENC2=$(bash "$SCRIPTS_DIR/savia-crypto.sh" encrypt "$KEYS_DIR/public.pem" "Same text" 2>/dev/null)
TOTAL=$((TOTAL + 1))
if [ "$ENC1" != "$ENC2" ]; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Two encryptions differ (random AES key)${NC}"
else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Encryption not idempotent${NC}"; fi

# ── Summary ───────────────────────────────────────────────────────
echo ""
echo "━━━ Results: $PASS/$TOTAL passed, $FAIL failed ━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
