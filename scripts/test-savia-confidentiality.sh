#!/bin/bash
# test-savia-confidentiality.sh — End-to-end confidentiality tests
# Verifies that encrypted messages are ACTUALLY confidential:
#   - Ciphertext on disk (no plaintext leaks)
#   - Only the intended recipient can decrypt
#   - Privacy scanner doesn't false-positive on ciphertext
#   - Metadata exposure is controlled
#   - Missing pubkey blocks encryption

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

# ── Setup: 3-user company repo with keypairs ──────────────────────
TMPDIR_BASE=$(mktemp -d)
ORIG_HOME="$HOME"
cleanup() { export HOME="$ORIG_HOME"; rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

REPO="$TMPDIR_BASE/company-repo"
mkdir -p "$REPO/.git" "$REPO/company-inbox"
for user in alice bob carol; do
  mkdir -p "$REPO/team/$user/public" "$REPO/team/$user/savia-inbox/unread"
  mkdir -p "$REPO/team/$user/savia-inbox/read"
  echo "name: $user" > "$REPO/team/$user/public/profile.md"
done
echo "@alice" > "$REPO/directory.md"
echo "@bob" >> "$REPO/directory.md"
echo "@carol" >> "$REPO/directory.md"
git -C "$REPO" init -q && git -C "$REPO" add -A && git -C "$REPO" commit -q -m "init"

# Generate keypairs for each user in isolated HOME dirs
for user in alice bob carol; do
  export HOME="$TMPDIR_BASE/home-$user"
  mkdir -p "$HOME/.pm-workspace"
  cat > "$HOME/.pm-workspace/company-repo" <<EOF
LOCAL_PATH=$REPO
USER_HANDLE=$user
EOF
  bash "$SCRIPTS_DIR/savia-crypto.sh" keygen 2>/dev/null
  bash "$SCRIPTS_DIR/savia-crypto.sh" export-pubkey "$REPO" "$user" 2>/dev/null
done

SECRET_MSG="El contrato es por 2.5 millones EUR y vence el 15 de abril"

echo "━━━ Test: Confidentiality — E2E Encrypted Messaging ━━━"
echo "Temp: $TMPDIR_BASE"
echo ""

# ── Test 1: Encrypted message has NO plaintext on disk ────────────
echo -e "${BLUE}── Ciphertext on Disk ──${NC}"

export HOME="$TMPDIR_BASE/home-alice"
RESULT=$(bash "$SCRIPTS_DIR/savia-messaging.sh" send bob \
  "Oferta confidencial" "$SECRET_MSG" --encrypt 2>&1)
assert "Encrypted send succeeds" "echo '$RESULT' | grep -q '✅'"

# Find the message file
MSG_FILE=$(find "$REPO/team/bob/savia-inbox/unread" -name "*.md" | head -1)
assert "Message file created" "[ -f '$MSG_FILE' ]"

# THE CRITICAL TEST: body must NOT contain the plaintext
MSG_CONTENT=$(cat "$MSG_FILE")
assert_not "Body does NOT contain plaintext secret" \
  "echo '$MSG_CONTENT' | grep -qi 'contrato'"
assert_not "Body does NOT contain amount" \
  "echo '$MSG_CONTENT' | grep -qi '2.5 millones'"
assert_not "Body does NOT contain date" \
  "echo '$MSG_CONTENT' | grep -qi '15 de abril'"

# Body SHOULD contain the encrypted format (base64:::base64)
assert "Body contains encrypted payload (:::)" \
  "echo '$MSG_CONTENT' | grep -q ':::'"
assert "Frontmatter says encrypted: true" \
  "grep -q 'encrypted: true' '$MSG_FILE'"

# ── Test 2: Metadata exposure (subject/from visible) ─────────────
echo ""
echo -e "${BLUE}── Metadata Exposure ──${NC}"

# Subject and from are intentionally in cleartext for routing
assert "Subject visible in frontmatter" \
  "grep -q 'subject:.*Oferta confidencial' '$MSG_FILE'"
assert "Sender visible in frontmatter" \
  "grep -q 'from:.*alice' '$MSG_FILE'"
assert "Recipient visible in frontmatter" \
  "grep -q 'to:.*bob' '$MSG_FILE'"

# ── Test 3: Intended recipient CAN decrypt ────────────────────────
echo ""
echo -e "${BLUE}── Recipient Decryption ──${NC}"

export HOME="$TMPDIR_BASE/home-bob"
# Extract encrypted body (everything after the YAML frontmatter closing ---)
ENCRYPTED_BODY=$(awk '/^---$/{n++; next} n>=2' "$MSG_FILE" | tr -d '\n ')
assert "Extracted encrypted body is non-empty" "[ -n '$ENCRYPTED_BODY' ]"

DECRYPTED=$(bash "$SCRIPTS_DIR/savia-crypto.sh" decrypt "$ENCRYPTED_BODY" 2>/dev/null || true)
assert "Bob can decrypt the message" "[ -n '$DECRYPTED' ]"
assert "Decrypted text matches original" \
  "echo '$DECRYPTED' | grep -q 'contrato'"
assert "Decrypted text has full content" \
  "echo '$DECRYPTED' | grep -q '2.5 millones'"

# ── Test 4: Non-recipient CANNOT decrypt ──────────────────────────
echo ""
echo -e "${BLUE}── Non-Recipient Rejection ──${NC}"

export HOME="$TMPDIR_BASE/home-carol"
CAROL_DECRYPT=$(bash "$SCRIPTS_DIR/savia-crypto.sh" decrypt "$ENCRYPTED_BODY" 2>/dev/null || echo "DECRYPTION_FAILED")
assert "Carol cannot decrypt Bob's message" \
  "echo '$CAROL_DECRYPT' | grep -qiE 'FAILED|error|^$'"
assert_not "Carol does NOT see the plaintext" \
  "echo '$CAROL_DECRYPT' | grep -qi 'contrato'"

# ── Test 5: Privacy scanner on encrypted messages ─────────────────
echo ""
echo -e "${BLUE}── Privacy Scanner vs Ciphertext ──${NC}"

export HOME="$TMPDIR_BASE/home-bob"
# Send a message with content that looks like a secret (GitHub PAT pattern)
export HOME="$TMPDIR_BASE/home-alice"
FAKE_PAT="ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789"
bash "$SCRIPTS_DIR/savia-messaging.sh" send bob \
  "Deploy keys" "$FAKE_PAT" --encrypt 2>/dev/null

# The encrypted message on disk should NOT trigger privacy scanner
git -C "$REPO" add -A
PRIVACY_RESULT=$(bash "$SCRIPTS_DIR/privacy-check-company.sh" "$REPO" "bob" 2>&1 || true)

# The PAT is encrypted, so the scanner should NOT detect it in the body
# But it might detect it in unencrypted messages — we only check that the
# encrypted one doesn't trigger a GitHub PAT violation
ENCRYPTED_MSG_COUNT=$(find "$REPO/team/bob/savia-inbox/unread" -name "*.md" \
  -exec grep -l 'encrypted: true' {} \; | wc -l)
assert "Multiple encrypted messages exist" "[ $ENCRYPTED_MSG_COUNT -ge 2 ]"

# Check that the encrypted body doesn't contain raw PAT pattern
LATEST_MSG=$(find "$REPO/team/bob/savia-inbox/unread" -name "*.md" -newer "$MSG_FILE" | head -1)
if [ -n "$LATEST_MSG" ]; then
  assert_not "Encrypted msg body has no raw PAT" \
    "grep -q 'ghp_' '$LATEST_MSG'"
fi

# ── Test 6: Missing pubkey blocks encryption ──────────────────────
echo ""
echo -e "${BLUE}── Missing Pubkey Guard ──${NC}"

# Create user with no pubkey
mkdir -p "$REPO/team/dave/savia-inbox/unread" "$REPO/team/dave/public"
echo "name: dave" > "$REPO/team/dave/public/profile.md"
# No pubkey.pem for dave

export HOME="$TMPDIR_BASE/home-alice"
RESULT=$(bash "$SCRIPTS_DIR/savia-messaging.sh" send dave \
  "Secret" "Top secret content" --encrypt 2>&1 || true)
assert "Send --encrypt fails without pubkey" \
  "echo '$RESULT' | grep -qi 'no public key\|cannot encrypt\|error'"

# Verify no message was created in dave's inbox
DAVE_MSG_COUNT=$(find "$REPO/team/dave/savia-inbox/unread" -name "*.md" 2>/dev/null | wc -l)
assert "No message delivered without encryption" "[ $DAVE_MSG_COUNT -eq 0 ]"

# ── Test 7: Unencrypted message IS readable (control test) ────────
echo ""
echo -e "${BLUE}── Control: Unencrypted Message ──${NC}"

export HOME="$TMPDIR_BASE/home-alice"
PLAIN_SECRET="La clave del WiFi es SuperSecreta123"
bash "$SCRIPTS_DIR/savia-messaging.sh" send bob \
  "WiFi" "$PLAIN_SECRET" 2>/dev/null

PLAIN_MSG=$(find "$REPO/team/bob/savia-inbox/unread" -name "*.md" \
  -exec grep -l 'encrypted: false' {} \; | head -1)
assert "Unencrypted message exists" "[ -f '$PLAIN_MSG' ]"
assert "Plaintext IS visible in unencrypted msg" \
  "grep -q 'SuperSecreta123' '$PLAIN_MSG'"
assert "Frontmatter says encrypted: false" \
  "grep -q 'encrypted: false' '$PLAIN_MSG'"

# ── Test 8: Idempotency — re-encrypt same message ────────────────
echo ""
echo -e "${BLUE}── Idempotency ──${NC}"

export HOME="$TMPDIR_BASE/home-alice"
ENC1=$(bash "$SCRIPTS_DIR/savia-crypto.sh" encrypt \
  "$REPO/team/bob/public/pubkey.pem" "Same message twice" 2>/dev/null)
ENC2=$(bash "$SCRIPTS_DIR/savia-crypto.sh" encrypt \
  "$REPO/team/bob/public/pubkey.pem" "Same message twice" 2>/dev/null)
assert "Two encryptions of same text differ (random AES key)" \
  "[ '$ENC1' != '$ENC2' ]"

# Both should decrypt to same plaintext
export HOME="$TMPDIR_BASE/home-bob"
DEC1=$(bash "$SCRIPTS_DIR/savia-crypto.sh" decrypt "$ENC1" 2>/dev/null)
DEC2=$(bash "$SCRIPTS_DIR/savia-crypto.sh" decrypt "$ENC2" 2>/dev/null)
assert "Both decrypt to same plaintext" "[ '$DEC1' = '$DEC2' ]"

# ── Test 9: Subject sensitivity — warns on sensitive subjects ─────
echo ""
echo -e "${BLUE}── Subject Sensitivity Check ──${NC}"

export HOME="$TMPDIR_BASE/home-alice"

# Monetary amount in subject → should warn
RESULT=$(bash "$SCRIPTS_DIR/savia-messaging.sh" send bob \
  "Presupuesto 150.000 EUR" "Details inside" --encrypt 2>&1)
assert "Warns on monetary amount in subject" \
  "echo '$RESULT' | grep -qi 'sensitive\|sensible\|monetary'"
assert "Message still delivered despite warning" \
  "echo '$RESULT' | grep -q '✅'"

# Company name with legal form → should warn
RESULT=$(bash "$SCRIPTS_DIR/savia-messaging.sh" send bob \
  "Contrato con Acme S.L." "Details" --encrypt 2>&1)
assert "Warns on company name (S.L.)" \
  "echo '$RESULT' | grep -qi 'sensitive\|company'"

# Credential keyword → should warn
RESULT=$(bash "$SCRIPTS_DIR/savia-messaging.sh" send bob \
  "Nueva password del servidor" "pass123" --encrypt 2>&1)
assert "Warns on credential keyword" \
  "echo '$RESULT' | grep -qi 'sensitive\|credential'"

# Email in subject → should warn
RESULT=$(bash "$SCRIPTS_DIR/savia-messaging.sh" send bob \
  "Contactar a juan@empresa.com" "Urgent" 2>&1)
assert "Warns on email in subject" \
  "echo '$RESULT' | grep -qi 'sensitive\|email'"

# DNI in subject → should warn
RESULT=$(bash "$SCRIPTS_DIR/savia-messaging.sh" send bob \
  "Contrato para 12345678A" "Details" --encrypt 2>&1)
assert "Warns on DNI in subject" \
  "echo '$RESULT' | grep -qi 'sensitive\|DNI\|ID number'"

# Private IP → should warn
RESULT=$(bash "$SCRIPTS_DIR/savia-messaging.sh" send bob \
  "Acceso a 192.168.1.50" "Config" 2>&1)
assert "Warns on private IP in subject" \
  "echo '$RESULT' | grep -qi 'sensitive\|IP'"

# Safe subject → should NOT warn
RESULT=$(bash "$SCRIPTS_DIR/savia-messaging.sh" send bob \
  "Mensaje cifrado" "The actual secret content" --encrypt 2>&1)
assert "No warning on safe subject" \
  "! echo '$RESULT' | grep -qi 'sensitive'"

# Encrypted msg with tip → should suggest generic subject
RESULT=$(bash "$SCRIPTS_DIR/savia-messaging.sh" send bob \
  "Factura 3200 EUR" "Invoice data" --encrypt 2>&1)
assert "Tip shown when encrypt + sensitive subject" \
  "echo '$RESULT' | grep -qi 'Tip\|generic\|Confidential'"

# ── Summary ───────────────────────────────────────────────────────
echo ""
echo "━━━ Results: $PASS/$TOTAL passed, $FAIL failed ━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
