#!/bin/bash
# test-company-repo.sh — Tests for company repo lifecycle
# Uso: bash scripts/test-company-repo.sh
#
# Tests repo creation, user connection, and sync using temp directories.

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

assert_file() {
  TOTAL=$((TOTAL + 1))
  if [ -f "$2" ]; then PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1 — file not found: $2${NC}"; fi
}

assert_dir() {
  TOTAL=$((TOTAL + 1))
  if [ -d "$2" ]; then PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1 — dir not found: $2${NC}"; fi
}

assert_contains() {
  TOTAL=$((TOTAL + 1))
  if grep -q "$3" "$2" 2>/dev/null; then PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1 — '$3' not in $2${NC}"; fi
}

# ── Setup ───────────────────────────────────────────────────────────
TMPDIR_BASE=$(mktemp -d)
BARE_REPO="$TMPDIR_BASE/bare-repo.git"
CLONE_A="$TMPDIR_BASE/clone-a"
CLONE_B="$TMPDIR_BASE/clone-b"
ORIG_CONFIG_DIR="$HOME/.pm-workspace"
TEST_CONFIG_DIR="$TMPDIR_BASE/pm-workspace-test"

cleanup() {
  rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

echo "━━━ Test: Company Repo ━━━"
echo "Temp dir: $TMPDIR_BASE"
echo ""

# ── Test 1: Template init ───────────────────────────────────────────
echo "── Test: Templates ──"

git init --bare "$BARE_REPO" 2>/dev/null
assert_ok "Bare repo created"

bash "$SCRIPTS_DIR/company-repo-templates.sh" init "$CLONE_A" "TestOrg" "admin-user"
assert_file "README.md created" "$CLONE_A/README.md"
assert_file "CODEOWNERS created" "$CLONE_A/CODEOWNERS"
assert_file "directory.md created" "$CLONE_A/directory.md"
assert_file "identity.md created" "$CLONE_A/company/identity.md"
assert_file "org-chart.md created" "$CLONE_A/company/org-chart.md"
assert_file "holidays.md created" "$CLONE_A/company/holidays.md"
assert_file "conventions.md created" "$CLONE_A/company/conventions.md"
assert_dir "company/inbox dir" "$CLONE_A/company/inbox"
assert_dir "users dir" "$CLONE_A/users"
assert_contains "CODEOWNERS has admin" "$CLONE_A/CODEOWNERS" "admin-user"
assert_contains "directory has admin" "$CLONE_A/directory.md" "@admin-user"

# ── Test 2: User folders ───────────────────────────────────────────
echo ""
echo "── Test: User Folders ──"

bash "$SCRIPTS_DIR/company-repo-templates.sh" user-folders "$CLONE_A" "dev-user" "Dev Name" "Developer"
assert_dir "User dir created" "$CLONE_A/users/dev-user"
assert_dir "Inbox unread" "$CLONE_A/users/dev-user/inbox/unread"
assert_dir "Inbox read" "$CLONE_A/users/dev-user/inbox/read"
assert_file "Profile created" "$CLONE_A/users/dev-user/profile.md"
assert_contains "Profile has name" "$CLONE_A/users/dev-user/profile.md" "Dev Name"
assert_contains "Directory updated" "$CLONE_A/directory.md" "@dev-user"
assert_contains "CODEOWNERS updated" "$CLONE_A/CODEOWNERS" "users/dev-user/"

# ── Test 3: Git operations ─────────────────────────────────────────
echo ""
echo "── Test: Git Operations ──"

cd "$CLONE_A"
git init 2>/dev/null
git remote add origin "$BARE_REPO" 2>/dev/null || true
git add -A 2>/dev/null
git commit -m "init" 2>/dev/null
git push -u origin HEAD 2>/dev/null
assert_ok "Initial push succeeded"

# Clone as second user
git clone "$BARE_REPO" "$CLONE_B" 2>/dev/null
assert_ok "Second user cloned"

bash "$SCRIPTS_DIR/company-repo-templates.sh" user-folders "$CLONE_B" "user-b" "User B" "Tester"
cd "$CLONE_B"
git add -A 2>/dev/null
git commit -m "user-b joined" 2>/dev/null
git push 2>/dev/null
assert_ok "Second user pushed"

# Pull from first clone
cd "$CLONE_A"
git pull 2>/dev/null
assert_dir "Sync: user-b visible" "$CLONE_A/users/user-b"
assert_ok "Sync pull succeeded"

# ── Summary ─────────────────────────────────────────────────────────
echo ""
echo "━━━ Results: $PASS/$TOTAL passed, $FAIL failed ━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
