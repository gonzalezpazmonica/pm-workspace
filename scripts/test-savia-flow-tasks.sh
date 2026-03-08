#!/bin/bash
# test-savia-flow-tasks.sh — Git-native task tests via savia-branch.sh
set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0; TOTAL=0; SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
assert() {
  TOTAL=$((TOTAL + 1))
  bash -c "$2" >/dev/null 2>&1 && { PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"; } \
    || { FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1${NC}"; }
}

# ── Setup: Bare repo + clone ──────────────────────────────────────
TMPDIR_BASE=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

BARE_REPO="$TMPDIR_BASE/company.git"
WORK_REPO="$TMPDIR_BASE/work"

git init --bare "$BARE_REPO"
git clone "$BARE_REPO" "$WORK_REPO"
cd "$WORK_REPO"

# Configure git user for commits
git config user.email "test@example.com"
git config user.name "Test User"

# Copy savia-branch.sh and savia-compat.sh
mkdir -p scripts
cp "$SCRIPTS_DIR/savia-branch.sh" scripts/
cp "$SCRIPTS_DIR/savia-compat.sh" scripts/
cp "$SCRIPTS_DIR/savia-flow-tasks.sh" scripts/

echo "━━━ Savia Flow — Git-Native Tasks (Branch-Based) ━━━"
echo "Bare: $BARE_REPO | Work: $WORK_REPO"
echo ""

echo -e "${BLUE}── Orphan Branches ──${NC}"
# Create team/backend orphan
git checkout --orphan team/backend 2>/dev/null || true
git rm -rf . 2>/dev/null || true
echo "# team/backend" > README.md
git add README.md && git commit -m "init: team/backend" && git push -u origin team/backend >/dev/null 2>&1
# Create user/alice orphan
git checkout --orphan user/alice 2>/dev/null || true
git rm -rf . 2>/dev/null || true
echo "# user/alice" > README.md
git add README.md && git commit -m "init: user/alice" && git push -u origin user/alice >/dev/null 2>&1
git checkout team/backend 2>/dev/null || true
assert "team/backend created" "git rev-parse --verify origin/team/backend >/dev/null 2>&1"
assert "user/alice created" "git rev-parse --verify origin/user/alice >/dev/null 2>&1"

echo ""
echo -e "${BLUE}── Task Create ──${NC}"
TASK="---
id: \"TASK-0001\"
type: \"task\"
title: \"Login endpoint\"
assigned: \"@alice\"
status: \"todo\"
priority: \"high\"
created: \"$(date +%Y-%m-%d)\"
---

## Acceptance Criteria
- [ ] OAuth2 support"
bash scripts/savia-branch.sh write . "team/backend" "projects/default/backlog/pbi-0001.md" "$TASK" "[flow: task-create] TASK-0001"
assert "Task written" "bash scripts/savia-branch.sh read . team/backend projects/default/backlog/pbi-0001.md | grep -q TASK-0001"
TASK_READ=$(bash scripts/savia-branch.sh read . team/backend projects/default/backlog/pbi-0001.md 2>/dev/null || echo "")
assert "Task readable" "[ -n '$TASK_READ' ] && echo '$TASK_READ' | grep -q 'Login endpoint'"

echo ""
echo -e "${BLUE}── Assign ──${NC}"
ASSIGN="task_id: TASK-0001
assigned_to: alice
date: $(date +%Y-%m-%d)"
bash scripts/savia-branch.sh write . "user/alice" "assignments/TASK-0001.md" "$ASSIGN" "[flow: assign] TASK-0001->alice"
assert "Assignment written" "bash scripts/savia-branch.sh read . user/alice assignments/TASK-0001.md | grep -q alice"

echo ""
echo -e "${BLUE}-- Status Transitions ──${NC}"
TASK_IN_PROG=$(echo "$TASK" | sed 's/status: "todo"/status: "in-progress"/')
bash scripts/savia-branch.sh write . "team/backend" "projects/default/backlog/pbi-0001.md" "$TASK_IN_PROG" "[flow: move] TASK-0001->in-progress"
assert "In-progress" "bash scripts/savia-branch.sh read . team/backend projects/default/backlog/pbi-0001.md | grep -q 'in-progress'"
TASK_DONE=$(echo "$TASK_IN_PROG" | sed 's/status: "in-progress"/status: "done"/')
bash scripts/savia-branch.sh write . "team/backend" "projects/default/backlog/pbi-0001.md" "$TASK_DONE" "[flow: move] TASK-0001->done"
assert "Done" "bash scripts/savia-branch.sh read . team/backend projects/default/backlog/pbi-0001.md | grep -q 'status: \"done\"'"

echo ""
echo -e "${BLUE}-- List Tasks ──${NC}"
TASK2="---
id: \"TASK-0002\"
type: \"bug\"
title: \"CSS broken on mobile\"
assigned: \"@bob\"
status: \"todo\"
priority: \"critical\"
created: \"$(date +%Y-%m-%d)\"
---"
bash scripts/savia-branch.sh write . "team/backend" "projects/default/backlog/pbi-0002.md" "$TASK2" "[flow: task-create] TASK-0002"
BACKLOG_LIST=$(bash scripts/savia-branch.sh list . "team/backend" "projects/default/backlog")
assert "Lists pbi-0001" "echo '$BACKLOG_LIST' | grep -q pbi-0001.md"
assert "Lists pbi-0002" "echo '$BACKLOG_LIST' | grep -q pbi-0002.md"

echo ""
echo -e "${BLUE}-- Error Handling ──${NC}"
assert "Read nonexistent fails" "! bash scripts/savia-branch.sh read . team/backend nonexistent.md 2>/dev/null"
assert "Branch exists fails" "! bash scripts/savia-branch.sh exists . nonexistent/branch 2>/dev/null"
echo ""
echo "━━━ Results: $PASS/$TOTAL passed, $FAIL failed ━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
