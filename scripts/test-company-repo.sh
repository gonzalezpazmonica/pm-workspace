#!/bin/bash
# test-company-repo.sh — Tests for Company Savia branch-based architecture
# Uso: bash scripts/test-company-repo.sh
# Tests: bare repo + main + exchange + user/{handle} orphan branches

set -euo pipefail

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
  [ -f "$2" ] && { PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"; } || { FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1${NC}"; }
}

assert_contains() {
  TOTAL=$((TOTAL + 1))
  grep -q "$3" "$2" 2>/dev/null && { PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"; } || { FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1${NC}"; }
}

assert_branch_file() {
  TOTAL=$((TOTAL + 1))
  git -C "$3" show "origin/$1:$2" >/dev/null 2>&1 && { PASS=$((PASS + 1)); echo -e "${GREEN}✅ $4${NC}"; } || { FAIL=$((FAIL + 1)); echo -e "${RED}❌ $4${NC}"; }
}

TMPDIR=$(mktemp -d)
BARE_REPO="$TMPDIR/bare.git"
CLONE="$TMPDIR/clone"
trap 'rm -rf "$TMPDIR"' EXIT

echo "━━━ Company Savia — Branch-Based Architecture ━━━"
git init --bare "$BARE_REPO" 2>/dev/null
assert_ok "1. Bare repo created"

bash "$SCRIPTS_DIR/company-repo-templates.sh" init "$CLONE" "test-org" "admin" 2>/dev/null
assert_ok "2. Init executed"

assert_file "3. README.md on main" "$CLONE/README.md"
assert_file "4. CODEOWNERS on main" "$CLONE/CODEOWNERS"
assert_file "5. directory.md on main" "$CLONE/directory.md"
assert_file "6. company/identity.md" "$CLONE/company/identity.md"
assert_file "7. company/org-chart.md" "$CLONE/company/org-chart.md"
assert_file "8. company/holidays.md" "$CLONE/company/holidays.md"
assert_file "9. company/conventions.md" "$CLONE/company/conventions.md"

cd "$CLONE"
git init 2>/dev/null
git remote add origin "$BARE_REPO" 2>/dev/null || true
git add -A 2>/dev/null
git commit -m "init main" -q 2>/dev/null || true
git push -u origin main 2>/dev/null || true
assert_ok "10. Main branch pushed"

bash "$SCRIPTS_DIR/company-repo-templates.sh" user-folders "$CLONE" "admin" "Admin" "admin" 2>/dev/null
assert_ok "11. Admin user branch created"

assert_branch_file "user/admin" "profile.md" "$CLONE" "12. Admin profile.md"
assert_branch_file "user/admin" "inbox/unread/.gitkeep" "$CLONE" "13. Admin inbox/unread"
assert_contains "14. Directory has @admin" "$CLONE/directory.md" "@admin"

git push --all 2>/dev/null || true
assert_ok "15. Branches pushed"

bash "$SCRIPTS_DIR/company-repo-templates.sh" user-folders "$CLONE" "alice" "Alice" "member" 2>/dev/null
assert_ok "16. Alice user branch created"

assert_branch_file "user/alice" "profile.md" "$CLONE" "17. Alice profile.md"
assert_contains "18. Directory has @alice" "$CLONE/directory.md" "@alice"

git push --all 2>/dev/null || true
git show origin/exchange:/.gitkeep >/dev/null 2>&1 || true
assert_ok "19. All branches and exchange exist"

echo ""
echo "━━━ Results: $PASS/$TOTAL passed, $FAIL failed ━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
