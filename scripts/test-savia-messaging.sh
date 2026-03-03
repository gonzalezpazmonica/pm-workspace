#!/bin/bash
# test-savia-messaging.sh — Tests for messaging round-trip
# Uso: bash scripts/test-savia-messaging.sh

set -euo pipefail

# ── Test harness ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0; TOTAL=0
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/savia-compat.sh"

assert_ok() {
  TOTAL=$((TOTAL + 1))
  if [ $? -eq 0 ]; then PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1${NC}"; fi
}
assert_file_exists() {
  TOTAL=$((TOTAL + 1))
  if ls $2 1>/dev/null 2>&1; then PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1 — no match: $2${NC}"; fi
}
assert_contains_file() {
  TOTAL=$((TOTAL + 1))
  local file; file=$(ls $2 2>/dev/null | head -1)
  if [ -n "$file" ] && grep -q "$3" "$file" 2>/dev/null; then
    PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1 — '$3' not found${NC}"; fi
}

# ── Setup ─────────────────────────────────────────────────────────
TMPDIR_BASE=$(mktemp -d)
REPO="$TMPDIR_BASE/company-repo"
ORIG_HOME="$HOME"
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

echo "━━━ Test: Savia Messaging ━━━"

bash "$SCRIPTS_DIR/company-repo-templates.sh" init "$REPO" "TestOrg" "alice"
bash "$SCRIPTS_DIR/company-repo-templates.sh" user-folders "$REPO" "alice" "Alice" "Admin"
bash "$SCRIPTS_DIR/company-repo-templates.sh" user-folders "$REPO" "bob" "Bob" "Developer"
cd "$REPO" && git init 2>/dev/null && git add -A && git commit -m "init" 2>/dev/null
cd "$TMPDIR_BASE"

export HOME="$TMPDIR_BASE"
mkdir -p "$HOME/.pm-workspace"
cat > "$HOME/.pm-workspace/company-repo" <<EOF
REPO_URL=file://$REPO
USER_HANDLE=alice
LOCAL_PATH=$REPO
ROLE=admin
EOF

# ── Test 1: Send ──────────────────────────────────────────────────
bash "$SCRIPTS_DIR/savia-messaging.sh" send "bob" "Hello Bob" "Test message" 2>/dev/null
assert_ok "Send command succeeded"
assert_file_exists "Message in bob inbox" "$REPO/users/bob/inbox/unread/*.md"
assert_contains_file "From field" "$REPO/users/bob/inbox/unread/*.md" 'from: "alice"'
assert_contains_file "Subject field" "$REPO/users/bob/inbox/unread/*.md" 'subject: "Hello Bob"'

# ── Test 2: Reply threading ───────────────────────────────────────
ORIG_ID=$(ls "$REPO/users/bob/inbox/unread/" | head -1 | sed 's/.md$//')
portable_sed_i 's/USER_HANDLE=alice/USER_HANDLE=bob/' "$HOME/.pm-workspace/company-repo"
bash "$SCRIPTS_DIR/savia-messaging.sh" reply "$ORIG_ID" "Got it, thanks!" 2>/dev/null
assert_ok "Reply command succeeded"
assert_file_exists "Reply in alice inbox" "$REPO/users/alice/inbox/unread/*.md"
REPLY_FILE=$(ls "$REPO/users/alice/inbox/unread/"*.md 2>/dev/null | head -1)
if [ -n "$REPLY_FILE" ]; then
  TOTAL=$((TOTAL + 1))
  if grep -q "thread:" "$REPLY_FILE" && grep -q "reply_to:" "$REPLY_FILE"; then
    PASS=$((PASS + 1)); echo -e "${GREEN}✅ Thread fields present${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Thread fields missing${NC}"; fi
fi

# ── Test 3: Announce ──────────────────────────────────────────────
portable_sed_i 's/USER_HANDLE=bob/USER_HANDLE=alice/' "$HOME/.pm-workspace/company-repo"
bash "$SCRIPTS_DIR/savia-messaging.sh" announce "Company Update" "New policy" 2>/dev/null
assert_ok "Announce command succeeded"
assert_file_exists "Announcement file" "$REPO/company/inbox/*.md"
assert_contains_file "Announcement type" "$REPO/company/inbox/*.md" 'type: "announcement"'

# ── Test 4: Read message ─────────────────────────────────────────
MSG_FILE=$(ls "$REPO/users/alice/inbox/unread/"*.md 2>/dev/null | head -1)
if [ -n "$MSG_FILE" ]; then
  MSG_ID=$(basename "$MSG_FILE" .md)
  bash "$SCRIPTS_DIR/savia-messaging.sh" read "$MSG_ID" >/dev/null 2>&1
  assert_ok "Read command succeeded"
  TOTAL=$((TOTAL + 1))
  if [ -f "$REPO/users/alice/inbox/read/${MSG_ID}.md" ]; then
    PASS=$((PASS + 1)); echo -e "${GREEN}✅ Message moved to read/${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Message not moved to read/${NC}"; fi
fi

# ── Test 5: Directory ─────────────────────────────────────────────
OUTPUT=$(bash "$SCRIPTS_DIR/savia-messaging.sh" directory 2>/dev/null)
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "@alice"; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Directory shows alice${NC}"
else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Directory missing alice${NC}"; fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "@bob"; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Directory shows bob${NC}"
else FAIL=$((FAIL + 1)); echo -e "${RED}❌ Directory missing bob${NC}"; fi

# ── Test 6: Broadcast ────────────────────────────────────────────
bash "$SCRIPTS_DIR/savia-messaging.sh" broadcast "All hands" "Meeting at 3pm" 2>/dev/null
assert_ok "Broadcast command succeeded"
assert_file_exists "Broadcast to bob" "$REPO/users/bob/inbox/unread/*.md"

# ── Test 7: Privacy check ────────────────────────────────────────
TOTAL=$((TOTAL + 1))
bash "$SCRIPTS_DIR/savia-messaging.sh" send "bob" "Creds" "Token: ghp_abcdefghijklmnopqrstuvwxyz1234567890" 2>/dev/null
if bash "$SCRIPTS_DIR/privacy-check-company.sh" "$REPO" "bob" 2>/dev/null; then
  FAIL=$((FAIL + 1)); echo -e "${RED}❌ Privacy should detect GitHub token${NC}"
else
  PASS=$((PASS + 1)); echo -e "${GREEN}✅ Privacy detected GitHub token${NC}"
fi

# ── Summary ───────────────────────────────────────────────────────
export HOME="$ORIG_HOME"
echo ""
echo "━━━ Results: $PASS/$TOTAL passed, $FAIL failed ━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
