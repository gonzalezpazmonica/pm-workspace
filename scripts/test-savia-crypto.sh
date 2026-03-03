#!/bin/bash
# test-savia-crypto.sh — Tests for E2E encryption
# Uso: bash scripts/test-savia-crypto.sh

set -euo pipefail

# ── Test harness ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0; TOTAL=0
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

assert_ok() {
  TOTAL=$((TOTAL + 1))
  if [ $? -eq 0 ]; then PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1${NC}"; fi
}

# ── Setup ─────────────────────────────────────────────────────────
TMPDIR_BASE=$(mktemp -d)
ORIG_HOME="$HOME"
export HOME="$TMPDIR_BASE"
KEYS_DIR="$HOME/.pm-workspace/savia-keys"
REPO_DIR="$TMPDIR_BASE/repo"
mkdir -p "$REPO_DIR/team/alice/public" "$REPO_DIR/team/bob/public"

cleanup() {
  export HOME="$ORIG_HOME"
  rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

echo "━━━ Test: Savia Crypto ━━━"

# ── Test 1: Keygen ────────────────────────────────────────────────
echo "── Keygen ──"
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

TOTAL=$((TOTAL + 1))
PERMS=$(stat -c '%a' "$KEYS_DIR/private.pem" 2>/dev/null || stat -f '%A' "$KEYS_DIR/private.pem" 2>/dev/null)
if [ "$PERMS" = "600" ]; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Private key permissions 600${NC}"
else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Private key permissions: $PERMS (expected 600)${NC}"; fi

# ── Test 2: Export pubkey ─────────────────────────────────────────
echo "── Export Pubkey ──"
bash "$SCRIPTS_DIR/savia-crypto.sh" export-pubkey "$REPO_DIR" "alice" 2>/dev/null
assert_ok "Export pubkey succeeded"

TOTAL=$((TOTAL + 1))
if [ -f "$REPO_DIR/team/alice/public/pubkey.pem" ]; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Pubkey exported to repo${NC}"
else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Pubkey not found in repo${NC}"; fi

# ── Test 3: Encrypt/decrypt round-trip ────────────────────────────
echo "── Encrypt/Decrypt Round-Trip ──"
PLAINTEXT="Hello, this is a secret message for testing!"
PUBKEY="$KEYS_DIR/public.pem"

ENCRYPTED=$(bash "$SCRIPTS_DIR/savia-crypto.sh" encrypt "$PUBKEY" "$PLAINTEXT" 2>/dev/null)
assert_ok "Encryption succeeded"

TOTAL=$((TOTAL + 1))
if echo "$ENCRYPTED" | grep -q ':::'; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Encrypted format has ::: separator${NC}"
else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Encrypted format invalid${NC}"; fi

DECRYPTED=$(bash "$SCRIPTS_DIR/savia-crypto.sh" decrypt "$ENCRYPTED" 2>/dev/null)
assert_ok "Decryption succeeded"

TOTAL=$((TOTAL + 1))
if [ "$DECRYPTED" = "$PLAINTEXT" ]; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Round-trip: plaintext matches${NC}"
else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Round-trip failed: got '$DECRYPTED'${NC}"; fi

# ── Test 4: Wrong key rejection ───────────────────────────────────
echo "── Wrong Key Rejection ──"
BOB_KEYS="$TMPDIR_BASE/bob-keys"
mkdir -p "$BOB_KEYS"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 \
  -out "$BOB_KEYS/private.pem" 2>/dev/null
openssl rsa -in "$BOB_KEYS/private.pem" -pubout \
  -out "$BOB_KEYS/public.pem" 2>/dev/null

ENCRYPTED_FOR_ALICE=$(bash "$SCRIPTS_DIR/savia-crypto.sh" encrypt "$PUBKEY" "Secret for Alice" 2>/dev/null)

mv "$KEYS_DIR/private.pem" "$KEYS_DIR/private.pem.bak"
cp "$BOB_KEYS/private.pem" "$KEYS_DIR/private.pem"

TOTAL=$((TOTAL + 1))
if bash "$SCRIPTS_DIR/savia-crypto.sh" decrypt "$ENCRYPTED_FOR_ALICE" 2>/dev/null; then
  FAIL=$((FAIL + 1)); echo -e "${RED}❌ Should fail with wrong key${NC}"
else
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Correctly rejected wrong key${NC}"
fi

mv "$KEYS_DIR/private.pem.bak" "$KEYS_DIR/private.pem"

# ── Test 5: Keygen idempotency ────────────────────────────────────
echo "── Keygen Idempotency ──"
TOTAL=$((TOTAL + 1))
if bash "$SCRIPTS_DIR/savia-crypto.sh" keygen 2>/dev/null; then
  FAIL=$((FAIL + 1)); echo -e "${RED}❌ Keygen without --force should warn${NC}"
else
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Keygen without --force warns${NC}"
fi

bash "$SCRIPTS_DIR/savia-crypto.sh" keygen --force 2>/dev/null
assert_ok "Keygen --force succeeds"

# ── Summary ───────────────────────────────────────────────────────
export HOME="$ORIG_HOME"
echo ""
echo "━━━ Results: $PASS/$TOTAL passed, $FAIL failed ━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
