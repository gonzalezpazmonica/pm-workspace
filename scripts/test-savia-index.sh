#!/bin/bash
# test-savia-index.sh — Tests for Git Persistence Engine (indexes)
# Uso: bash scripts/test-savia-index.sh
#
# Tests index CRUD, rebuild, compact, verify — all in temp dir.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0; TOTAL=0
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

assert() {
  TOTAL=$((TOTAL + 1))
  if eval "$2" >/dev/null 2>&1; then PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1${NC}"; fi
}

assert_eq() {
  TOTAL=$((TOTAL + 1))
  if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1 — got '$2', want '$3'${NC}"; fi
}

# ── Setup ────────────────────────────────────────────────────────────
TMPDIR_BASE=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

cd "$TMPDIR_BASE"
mkdir -p scripts
cp "$SCRIPTS_DIR/savia-index.sh" scripts/
cp "$SCRIPTS_DIR/savia-index-rebuild.sh" scripts/
[ -f "$SCRIPTS_DIR/savia-compat.sh" ] && cp "$SCRIPTS_DIR/savia-compat.sh" scripts/

echo "━━━ Test: Git Persistence Engine ━━━"
echo "Temp: $TMPDIR_BASE"
echo ""

# ── Test 1: Init & lookup ────────────────────────────────────────────
echo -e "${BLUE}── Index Init & Lookup ──${NC}"

RESULT=$(bash scripts/savia-index.sh lookup profiles alice 2>&1 || true)
assert "Lookup on missing index returns INDEX_NOT_FOUND" "echo '$RESULT' | grep -q 'INDEX_NOT_FOUND'"

mkdir -p .savia-index
printf "handle\tpath\trole\tupdated\n" > .savia-index/profiles.idx
printf "alice\tusers/alice/profile.md\tAdmin\t2026-03-03\n" >> .savia-index/profiles.idx
printf "bob\tusers/bob/profile.md\tMember\t2026-03-02\n" >> .savia-index/profiles.idx

RESULT=$(bash scripts/savia-index.sh lookup profiles alice)
assert "Lookup alice finds entry" "echo '$RESULT' | grep -q 'alice'"

RESULT=$(bash scripts/savia-index.sh lookup profiles carol 2>&1 || true)
assert "Lookup carol returns NOT_FOUND" "echo '$RESULT' | grep -q 'NOT_FOUND'"

# ── Test 2: Update entry ─────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Update Entry ──${NC}"

bash scripts/savia-index.sh update profiles carol "users/carol/profile.md" "Dev" "2026-03-03"
RESULT=$(bash scripts/savia-index.sh lookup profiles carol)
assert "Update adds new entry" "echo '$RESULT' | grep -q 'carol'"

bash scripts/savia-index.sh update profiles alice "users/alice/profile.md" "SuperAdmin" "2026-03-03"
COUNT=$(grep -c "^alice" .savia-index/profiles.idx)
assert_eq "Update replaces (no duplicates)" "$COUNT" "1"

RESULT=$(bash scripts/savia-index.sh lookup profiles alice)
assert "Updated alice has new role" "echo '$RESULT' | grep -q 'SuperAdmin'"

# ── Test 3: Remove entry ─────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Remove Entry ──${NC}"

bash scripts/savia-index.sh remove profiles bob
RESULT=$(bash scripts/savia-index.sh lookup profiles bob 2>&1)
assert "Remove bob succeeds" "echo '$RESULT' | grep -q 'NOT_FOUND'"

# ── Test 4: Verify ───────────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Verify Index ──${NC}"

RESULT=$(bash scripts/savia-index.sh verify profiles)
assert "Verify returns metadata" "echo '$RESULT' | grep -q 'index=profiles'"
assert "Verify shows entry count" "echo '$RESULT' | grep -q 'entries='"

# ── Test 5: Compact ──────────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Compact ──${NC}"

mkdir -p users/alice
echo "# Alice" > users/alice/identity.md
# carol has no identity.md → should be compacted
BEFORE=$(wc -l < .savia-index/profiles.idx)
bash scripts/savia-index.sh compact profiles
AFTER=$(wc -l < .savia-index/profiles.idx)
assert "Compact removes orphaned entries" "[ $AFTER -lt $BEFORE ]"

# ── Test 6: Idempotency ──────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Idempotency ──${NC}"

bash scripts/savia-index.sh compact profiles
bash scripts/savia-index.sh compact profiles
FINAL=$(wc -l < .savia-index/profiles.idx)
assert_eq "Double compact is idempotent" "$AFTER" "$FINAL"

# ── Test 7: Messages index ───────────────────────────────────────────
echo ""
echo -e "${BLUE}── Messages Index ──${NC}"

printf "thread_id\tpath\tfrom\tdate\tsubject\n" > .savia-index/messages.idx
printf "MSG-001\tinbox/MSG-001.md\t@alice\t2026-03-03\tHello\n" >> .savia-index/messages.idx

RESULT=$(bash scripts/savia-index.sh lookup messages MSG-001)
assert "Messages index lookup works" "echo '$RESULT' | grep -q 'Hello'"

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "━━━ Results: $PASS/$TOTAL passed, $FAIL failed ━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
