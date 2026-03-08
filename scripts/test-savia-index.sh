#!/bin/bash
# test-savia-index.sh — Tests for indexes on branch-based architecture
set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0; TOTAL=0
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
assert() {
  TOTAL=$((TOTAL+1))
  if bash -c "$2" >/dev/null 2>&1; then PASS=$((PASS+1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL+1)); echo -e "${RED}❌ $1${NC}"; fi
}
assert_eq() {
  TOTAL=$((TOTAL+1))
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL+1)); echo -e "${RED}❌ $1 — got '$2', want '$3'${NC}"; fi
}

TMPDIR_BASE=$(mktemp -d); REPO="$TMPDIR_BASE/repo"; CLONE="$TMPDIR_BASE/clone"
cleanup() { rm -rf "$TMPDIR_BASE"; }; trap cleanup EXIT
mkdir -p "$REPO" && cd "$REPO" && git init --bare >/dev/null 2>&1
git clone "$REPO" "$CLONE" >/dev/null 2>&1 && cd "$CLONE"
mkdir -p .savia-index users/alice users/bob
printf "handle\tpath\trole\tupdated\n" > .savia-index/profiles.idx
printf "alice\tusers/alice/profile.md\tAdmin\t2026-03-03\n" >> .savia-index/profiles.idx
printf "bob\tusers/bob/profile.md\tMember\t2026-03-02\n" >> .savia-index/profiles.idx
echo "# Alice Profile" > users/alice/profile.md
echo "# Bob Profile" > users/bob/profile.md
git add . && git commit -m "init: indexes and profiles" >/dev/null 2>&1
git push origin main >/dev/null 2>&1
echo "━━━ Test: Index System ━━━"; echo ""
echo -e "${BLUE}── Index Rebuild ──${NC}"
WTDIR1=$(mktemp -d)
cd "$WTDIR1" && git init >/dev/null 2>&1 && git remote add origin "$REPO"
git checkout --orphan user/alice 2>/dev/null
mkdir -p alice && echo "# Alice" > alice/profile.md
git add . && git commit -m "init: user/alice" >/dev/null 2>&1
git push origin user/alice >/dev/null 2>&1 || true
cd "$CLONE" && rm -rf "$WTDIR1"
assert "Index read succeeds" "grep -q 'alice' .savia-index/profiles.idx"
echo -e "${BLUE}── Index Format & Lookup ──${NC}"
assert "profiles.idx has tab-delimited format" "grep -q 'alice.*Admin' .savia-index/profiles.idx"
RESULT=$(grep "^alice" .savia-index/profiles.idx)
assert "Lookup alice finds entry" "echo '$RESULT' | grep -q alice"
assert "Lookup unknown returns empty" "! grep -q '^carol' .savia-index/profiles.idx"

echo -e "${BLUE}── Update Entry ──${NC}"
printf "carol\tusers/carol/profile.md\tDev\t2026-03-03\n" >> .savia-index/profiles.idx
assert "Update adds new entry" "grep -q 'carol' .savia-index/profiles.idx"
sed -i '/^alice\t/d' .savia-index/profiles.idx
printf "alice\tusers/alice/profile.md\tSuperAdmin\t2026-03-03\n" >> .savia-index/profiles.idx
AFTER_COUNT=$(grep "^alice" .savia-index/profiles.idx | wc -l)
assert_eq "Update replaces (no duplicates)" "$AFTER_COUNT" "1"
assert "Updated alice has new role" "grep 'alice' .savia-index/profiles.idx | grep -q 'SuperAdmin'"
echo -e "${BLUE}── Remove Entry ──${NC}"
sed -i '/^bob\t/d' .savia-index/profiles.idx
assert "Remove bob succeeds" "! grep -q '^bob' .savia-index/profiles.idx"
echo -e "${BLUE}── Verify Index ──${NC}"
ENTRY_COUNT=$(tail -n +2 .savia-index/profiles.idx | wc -l)
assert "Verify returns entry count" "[ $ENTRY_COUNT -gt 0 ]"
assert "Verify shows index metadata" "[ -f .savia-index/profiles.idx ]"
echo -e "${BLUE}── Compact ──${NC}"
mkdir -p users/alice
BEFORE_LINES=$(wc -l < .savia-index/profiles.idx)
sed -i '/^carol\t/d' .savia-index/profiles.idx
AFTER_LINES=$(wc -l < .savia-index/profiles.idx)
assert "Compact removes orphaned entries" "[ $AFTER_LINES -le $BEFORE_LINES ]"
echo -e "${BLUE}── Idempotency ──${NC}"
BEFORE_COMPACT=$(wc -l < .savia-index/profiles.idx)
AFTER_COMPACT=$(wc -l < .savia-index/profiles.idx)
assert_eq "Double compact is idempotent" "$AFTER_COMPACT" "$BEFORE_COMPACT"
echo -e "${BLUE}── Alternate Indexes ──${NC}"
printf "user\tinbox_count\tupdated\n" > .savia-index/inboxes.idx
printf "alice\t3\t2026-03-03\n" >> .savia-index/inboxes.idx
printf "bob\t1\t2026-03-02\n" >> .savia-index/inboxes.idx
assert "Inboxes index created" "[ -f .savia-index/inboxes.idx ]"
assert "Inboxes index lookup works" "grep -q 'alice' .savia-index/inboxes.idx"
printf "team_name\tmembers\tupdated\n" > .savia-index/teams.idx
printf "backend\talice,bob\t2026-03-03\n" >> .savia-index/teams.idx
printf "frontend\tcarol\t2026-03-02\n" >> .savia-index/teams.idx
assert "Teams index created" "[ -f .savia-index/teams.idx ]"
TEAM_COUNT=$(tail -n +2 .savia-index/teams.idx | wc -l)
assert "Teams index has entries" "[ $TEAM_COUNT -gt 0 ]"
echo ""
echo "━━━ Results: $PASS/$TOTAL passed, $FAIL failed ━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
