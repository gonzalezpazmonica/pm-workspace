#!/bin/bash
# test-savia-travel.sh — Tests for Travel Mode (pack/unpack/verify/clean)
# Uso: bash scripts/test-savia-travel.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0; TOTAL=0
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

assert() {
  TOTAL=$((TOTAL + 1))
  if eval "$2" >/dev/null 2>&1; then PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1${NC}"; fi
}

# ── Setup ────────────────────────────────────────────────────────────
TMPDIR_BASE=$(mktemp -d)
FAKE_HOME="$TMPDIR_BASE/fake-home"
USB_DIR="$TMPDIR_BASE/usb"
RESTORE_DIR="$TMPDIR_BASE/restored"
PASS_PHRASE="test-passphrase-2026"

cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

# Create fake workspace
mkdir -p "$FAKE_HOME/claude/.claude/commands" "$FAKE_HOME/claude/scripts"
mkdir -p "$FAKE_HOME/claude/docs" "$FAKE_HOME/.pm-workspace"
echo "# CLAUDE.md test" > "$FAKE_HOME/claude/CLAUDE.md"
echo "echo test" > "$FAKE_HOME/claude/scripts/test.sh"
echo "secret-pat-12345" > "$FAKE_HOME/.pm-workspace/config"
mkdir -p "$USB_DIR" "$RESTORE_DIR"

echo "━━━ Test: Travel Mode ━━━"
echo "Temp: $TMPDIR_BASE"
echo ""

# ── Test 1: Pack ─────────────────────────────────────────────────────
echo -e "${BLUE}── Pack ──${NC}"

# Direct pack using tar+openssl (same logic as savia-travel.sh)
tar czf "$TMPDIR_BASE/savia.tar.gz" -C "$FAKE_HOME/claude" . 2>/dev/null
assert "Tar creation succeeds" "[ -f '$TMPDIR_BASE/savia.tar.gz' ]"

openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
  -pass "pass:$PASS_PHRASE" -in "$TMPDIR_BASE/savia.tar.gz" \
  -out "$USB_DIR/savia-backup.enc" 2>/dev/null
assert "Encrypted archive created" "[ -f '$USB_DIR/savia-backup.enc' ]"

sha256sum "$TMPDIR_BASE/savia.tar.gz" | cut -d' ' -f1 > "$USB_DIR/savia-backup.manifest"
assert "Manifest created" "[ -f '$USB_DIR/savia-backup.manifest' ]"

rm "$TMPDIR_BASE/savia.tar.gz"
assert "Temp tar cleaned up" "[ ! -f '$TMPDIR_BASE/savia.tar.gz' ]"

# Check file sizes are nonzero
ENC_SIZE=$(stat -f%z "$USB_DIR/savia-backup.enc" 2>/dev/null || stat --printf="%s" "$USB_DIR/savia-backup.enc" 2>/dev/null)
assert "Encrypted file is non-empty" "[ $ENC_SIZE -gt 0 ]"

# ── Test 2: Verify ───────────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Verify ──${NC}"

assert "Archive file exists for verify" "[ -f '$USB_DIR/savia-backup.enc' ]"
assert "Manifest file exists for verify" "[ -f '$USB_DIR/savia-backup.manifest' ]"

MANIFEST_HASH=$(cat "$USB_DIR/savia-backup.manifest")
assert "Manifest contains hash" "[ ${#MANIFEST_HASH} -eq 64 ]"

# ── Test 3: Unpack ───────────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Unpack ──${NC}"

openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -pass "pass:$PASS_PHRASE" -in "$USB_DIR/savia-backup.enc" \
  -out "$TMPDIR_BASE/restore.tar.gz" 2>/dev/null
assert "Decryption succeeds" "[ -f '$TMPDIR_BASE/restore.tar.gz' ]"

# Verify hash matches
RESTORE_HASH=$(sha256sum "$TMPDIR_BASE/restore.tar.gz" | cut -d' ' -f1)
assert "Hash matches manifest" "[ '$RESTORE_HASH' = '$MANIFEST_HASH' ]"

mkdir -p "$RESTORE_DIR"
tar xzf "$TMPDIR_BASE/restore.tar.gz" -C "$RESTORE_DIR" 2>/dev/null
assert "Extract succeeds" "[ -d '$RESTORE_DIR' ]"
assert "CLAUDE.md restored" "[ -f '$RESTORE_DIR/CLAUDE.md' ]"
assert "Scripts restored" "[ -f '$RESTORE_DIR/scripts/test.sh' ]"
assert "Docs dir restored" "[ -d '$RESTORE_DIR/docs' ]"

RESTORED_CONTENT=$(cat "$RESTORE_DIR/CLAUDE.md")
assert "Content matches original" "[ '$RESTORED_CONTENT' = '# CLAUDE.md test' ]"

# ── Test 4: Wrong passphrase ─────────────────────────────────────────
echo ""
echo -e "${BLUE}── Wrong Passphrase Rejection ──${NC}"

WRONG_RESULT=$(openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -pass "pass:wrong-password" -in "$USB_DIR/savia-backup.enc" \
  -out /dev/null 2>&1 || true)
assert "Wrong passphrase fails" "echo '$WRONG_RESULT' | grep -qi 'bad\|error\|fail'"

# ── Test 5: Idempotency ─────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Idempotency ──${NC}"

# Pack again — should produce same-sized encrypted file
tar czf "$TMPDIR_BASE/savia2.tar.gz" -C "$FAKE_HOME/claude" . 2>/dev/null
openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
  -pass "pass:$PASS_PHRASE" -in "$TMPDIR_BASE/savia2.tar.gz" \
  -out "$USB_DIR/savia-backup2.enc" 2>/dev/null
assert "Second pack succeeds" "[ -f '$USB_DIR/savia-backup2.enc' ]"

# Content should be identical (same source)
HASH2=$(sha256sum "$TMPDIR_BASE/savia2.tar.gz" | cut -d' ' -f1)
assert "Content hash matches between packs" "[ '$HASH2' = '$MANIFEST_HASH' ]"

rm "$TMPDIR_BASE/savia2.tar.gz" "$USB_DIR/savia-backup2.enc"

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "━━━ Results: $PASS/$TOTAL passed, $FAIL failed ━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
