#!/bin/bash
# test-savia-flow.sh — Tests for Savia Flow on branch-based architecture (~25 tests)
# Tests PBI lifecycle, assignments, sprints, timesheets on team/ and user/ branches

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0; TOTAL=0
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/savia-compat.sh"
source "$SCRIPTS_DIR/savia-branch.sh"

assert_file() {
  TOTAL=$((TOTAL + 1))
  if git -C "$REPO" show "${2}:${3}" >/dev/null 2>&1; then
    PASS=$((PASS + 1)); echo -e "${GREEN}✓${NC} $1"
  else FAIL=$((FAIL + 1)); echo -e "${RED}✗${NC} $1"; fi
}

assert_contains() {
  TOTAL=$((TOTAL + 1))
  local content=$(git -C "$REPO" show "${3}:${2}" 2>/dev/null || echo "")
  if echo "$content" | grep -q "$4"; then
    PASS=$((PASS + 1)); echo -e "${GREEN}✓${NC} $1"
  else FAIL=$((FAIL + 1)); echo -e "${RED}✗${NC} $1"; fi
}

setup_branch_repo() {
  TMPDIR_BASE=$(mktemp -d)
  REPO="$TMPDIR_BASE/repo"
  CLONE="$TMPDIR_BASE/clone"
  mkdir -p "$REPO" && cd "$REPO" && git init --bare
  git clone "$REPO" "$CLONE" >/dev/null 2>&1
  cd "$CLONE" && echo "# Savia" > README.md && git add README.md
  git commit -m "init: main" && git push origin main >/dev/null 2>&1
  bash "$SCRIPTS_DIR/savia-branch.sh" ensure-orphan "$REPO" "team/backend" "init: team/backend" 2>/dev/null
  bash "$SCRIPTS_DIR/savia-branch.sh" ensure-orphan "$REPO" "user/alice" "init: user/alice" 2>/dev/null
  bash "$SCRIPTS_DIR/savia-branch.sh" ensure-orphan "$REPO" "user/bob" "init: user/bob" 2>/dev/null
  git -C "$CLONE" fetch --all >/dev/null 2>&1
  cd "$CLONE"
}

cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

echo "--- Test: Savia Flow (Branch-Based) ---"
setup_branch_repo

echo ""
echo "── Project Initialization ──"
bash "$SCRIPTS_DIR/savia-branch.sh" write "$REPO" "team/backend" \
  "projects/webapp/backlog/.gitkeep" "" "init: project structure" 2>/dev/null
assert_file "Backlog exists" "team/backend" "projects/webapp/backlog/.gitkeep"

bash "$SCRIPTS_DIR/savia-branch.sh" write "$REPO" "team/backend" \
  "projects/webapp/sprints/.gitkeep" "" "init: sprints" 2>/dev/null
assert_file "Sprints exists" "team/backend" "projects/webapp/sprints/.gitkeep"

bash "$SCRIPTS_DIR/savia-branch.sh" write "$REPO" "team/backend" \
  "projects/webapp/specs/.gitkeep" "" "init: specs" 2>/dev/null
assert_file "Specs exists" "team/backend" "projects/webapp/specs/.gitkeep"

echo ""
echo "── PBI Lifecycle ──"
PBI1="---\nid: PBI-001\ntitle: Login page\nstatus: new\nprior: high\n---\nBuild login"
bash "$SCRIPTS_DIR/savia-branch.sh" write "$REPO" "team/backend" \
  "projects/webapp/backlog/pbi-001.md" "$PBI1" "flow: create PBI-001" 2>/dev/null
assert_file "PBI-001 created" "team/backend" "projects/webapp/backlog/pbi-001.md"
assert_contains "PBI title" "projects/webapp/backlog/pbi-001.md" "team/backend" "Login page"
assert_contains "PBI status new" "projects/webapp/backlog/pbi-001.md" "team/backend" "new"

PBI2="---\nid: PBI-002\ntitle: Dashboard\nstatus: new\n---"
bash "$SCRIPTS_DIR/savia-branch.sh" write "$REPO" "team/backend" \
  "projects/webapp/backlog/pbi-002.md" "$PBI2" "flow: create PBI-002" 2>/dev/null
assert_file "PBI-002 created" "team/backend" "projects/webapp/backlog/pbi-002.md"

echo ""
echo "── Assignment ──"
ASSIGN="---\nid: PBI-001\nassigned: alice\n---"
bash "$SCRIPTS_DIR/savia-branch.sh" write "$REPO" "user/alice" \
  "flow/assigned/PBI-001.md" "$ASSIGN" "flow: assign" 2>/dev/null
assert_file "Assignment on user/alice" "user/alice" "flow/assigned/PBI-001.md"

PBI1_A="---\nid: PBI-001\ntitle: Login page\nstatus: ready\nassignee: alice\n---"
bash "$SCRIPTS_DIR/savia-branch.sh" write "$REPO" "team/backend" \
  "projects/webapp/backlog/pbi-001.md" "$PBI1_A" "flow: assign" 2>/dev/null
assert_contains "Assignee updated" "projects/webapp/backlog/pbi-001.md" "team/backend" "alice"

echo ""
echo "── State Machine ──"
PBI1_IP="---\nid: PBI-001\nstatus: in-progress\n---"
bash "$SCRIPTS_DIR/savia-branch.sh" write "$REPO" "team/backend" \
  "projects/webapp/backlog/pbi-001.md" "$PBI1_IP" "flow: move" 2>/dev/null
assert_contains "Status in-progress" "projects/webapp/backlog/pbi-001.md" "team/backend" "in-progress"

PBI1_R="---\nid: PBI-001\nstatus: review\n---"
bash "$SCRIPTS_DIR/savia-branch.sh" write "$REPO" "team/backend" \
  "projects/webapp/backlog/pbi-001.md" "$PBI1_R" "flow: move" 2>/dev/null
assert_contains "Status review" "projects/webapp/backlog/pbi-001.md" "team/backend" "review"

bash "$SCRIPTS_DIR/savia-branch.sh" write "$REPO" "team/backend" \
  "projects/webapp/backlog/archive/pbi-001.md" "$PBI1_R" "flow: archive" 2>/dev/null
assert_file "Archived" "team/backend" "projects/webapp/backlog/archive/pbi-001.md"

echo ""
echo "── Timesheet ──"
MONTH=$(date +%Y-%m)
SHEET="---\nmonth: $MONTH\nuser: alice\n---\n| 2026-03-03 | PBI-002 | 4 |"
bash "$SCRIPTS_DIR/savia-branch.sh" write "$REPO" "user/alice" \
  "flow/timesheet/$MONTH.md" "$SHEET" "flow: log hours" 2>/dev/null
assert_file "Timesheet created" "user/alice" "flow/timesheet/$MONTH.md"
assert_contains "PBI in timesheet" "flow/timesheet/$MONTH.md" "user/alice" "PBI-002"

echo ""
echo "── Sprint ──"
SPRINT="---\nid: sprint-2026-01\ngoal: MVP\nstatus: active\n---"
bash "$SCRIPTS_DIR/savia-branch.sh" write "$REPO" "team/backend" \
  "projects/webapp/sprints/sprint-2026-01/sprint.md" "$SPRINT" "flow: create sprint" 2>/dev/null
assert_file "Sprint created" "team/backend" "projects/webapp/sprints/sprint-2026-01/sprint.md"
assert_contains "Sprint active" "projects/webapp/sprints/sprint-2026-01/sprint.md" "team/backend" "active"

SPRINT_C="---\nid: sprint-2026-01\nstatus: closed\n---"
bash "$SCRIPTS_DIR/savia-branch.sh" write "$REPO" "team/backend" \
  "projects/webapp/sprints/sprint-2026-01/sprint.md" "$SPRINT_C" "flow: close" 2>/dev/null
assert_contains "Sprint closed" "projects/webapp/sprints/sprint-2026-01/sprint.md" "team/backend" "closed"

echo ""
echo "── Board & Metrics ──"
TOTAL=$((TOTAL + 1))
if bash "$SCRIPTS_DIR/savia-branch.sh" list "$REPO" "team/backend" "projects/webapp/backlog" | grep -q "."; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✓${NC} Board renders"
else FAIL=$((FAIL + 1)); echo -e "${RED}✗${NC} Board empty"; fi

TOTAL=$((TOTAL + 1))
if [ -n "$(bash "$SCRIPTS_DIR/savia-branch.sh" list "$REPO" "team/backend" "projects/webapp/backlog" 2>/dev/null)" ]; then
  PASS=$((PASS + 1)); echo -e "${GREEN}✓${NC} Metrics available"
else FAIL=$((FAIL + 1)); echo -e "${RED}✗${NC} Metrics missing"; fi

echo ""
echo "--- Results: $PASS/$TOTAL passed, $FAIL failed ---"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
