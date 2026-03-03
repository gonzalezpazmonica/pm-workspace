#!/bin/bash
# test-savia-flow.sh — Tests for Savia Flow (Git-based PM)
# Uso: bash scripts/test-savia-flow.sh

set -euo pipefail

# ── Test harness ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0; TOTAL=0
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/savia-compat.sh"

assert_ok() {
  TOTAL=$((TOTAL + 1))
  if [ $? -eq 0 ]; then PASS=$((PASS + 1)); echo -e "${GREEN}OK${NC} $1"
  else FAIL=$((FAIL + 1)); echo -e "${RED}FAIL${NC} $1"; fi
}
assert_file() {
  TOTAL=$((TOTAL + 1))
  if [ -f "$2" ]; then PASS=$((PASS + 1)); echo -e "${GREEN}OK${NC} $1"
  else FAIL=$((FAIL + 1)); echo -e "${RED}FAIL${NC} $1 — missing: $2"; fi
}
assert_dir() {
  TOTAL=$((TOTAL + 1))
  if [ -d "$2" ]; then PASS=$((PASS + 1)); echo -e "${GREEN}OK${NC} $1"
  else FAIL=$((FAIL + 1)); echo -e "${RED}FAIL${NC} $1 — missing: $2"; fi
}
assert_contains() {
  TOTAL=$((TOTAL + 1))
  if grep -q "$3" "$2" 2>/dev/null; then PASS=$((PASS + 1)); echo -e "${GREEN}OK${NC} $1"
  else FAIL=$((FAIL + 1)); echo -e "${RED}FAIL${NC} $1 — '$3' not in $2"; fi
}

# ── Setup ───────────────────────────────────────────────────────────
TMPDIR_BASE=$(mktemp -d)
REPO="$TMPDIR_BASE/company-repo"
ORIG_HOME="$HOME"
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

echo "--- Test: Savia Flow ---"

# Prepare fake company repo
mkdir -p "$REPO"
cd "$REPO" && git init -q && cd "$TMPDIR_BASE"

export HOME="$TMPDIR_BASE"
mkdir -p "$HOME/.pm-workspace"
cat > "$HOME/.pm-workspace/company-repo" <<EOF
REPO_URL=file://$REPO
USER_HANDLE=alice
LOCAL_PATH=$REPO
ROLE=admin
EOF

# Create user dir for alice
mkdir -p "$REPO/team/alice/savia-flow"

# ── Test 1: Init project structure ──────────────────────────────────
bash "$SCRIPTS_DIR/savia-flow.sh" init-project "alpha" "dev-team" 2>/dev/null
assert_ok "Init project succeeded"
assert_dir "Backlog dir" "$REPO/projects/alpha/backlog"
assert_dir "Archive dir" "$REPO/projects/alpha/backlog/archive"
assert_dir "Sprints dir" "$REPO/projects/alpha/sprints"
assert_file "Current pointer" "$REPO/projects/alpha/sprints/current.md"

# ── Test 2: Create PBI ─────────────────────────────────────────────
bash "$SCRIPTS_DIR/savia-flow.sh" create-pbi "alpha" "Login page" "Build login" "high" "5" 2>/dev/null
assert_ok "Create PBI succeeded"
assert_file "PBI file exists" "$REPO/projects/alpha/backlog/pbi-001.md"
assert_contains "PBI has title" "$REPO/projects/alpha/backlog/pbi-001.md" 'title: "Login page"'
assert_contains "PBI status new" "$REPO/projects/alpha/backlog/pbi-001.md" 'status: "new"'

# Create second PBI
bash "$SCRIPTS_DIR/savia-flow.sh" create-pbi "alpha" "Dashboard" "Main dashboard" "medium" "3" 2>/dev/null
assert_file "Second PBI" "$REPO/projects/alpha/backlog/pbi-002.md"

# ── Test 3: Assign PBI ─────────────────────────────────────────────
bash "$SCRIPTS_DIR/savia-flow.sh" assign "alpha" "PBI-001" "alice" 2>/dev/null
assert_ok "Assign succeeded"
assert_contains "Assignee set" "$REPO/projects/alpha/backlog/pbi-001.md" 'assignee: "alice"'
assert_file "Assigned copy" "$REPO/team/alice/savia-flow/assigned/PBI-001.md"

# ── Test 4: Move PBI through states ────────────────────────────────
bash "$SCRIPTS_DIR/savia-flow.sh" move "alpha" "PBI-001" "ready" 2>/dev/null
assert_contains "Status ready" "$REPO/projects/alpha/backlog/pbi-001.md" 'status: "ready"'

bash "$SCRIPTS_DIR/savia-flow.sh" move "alpha" "PBI-001" "in-progress" 2>/dev/null
assert_contains "Status in-progress" "$REPO/projects/alpha/backlog/pbi-001.md" 'status: "in-progress"'

bash "$SCRIPTS_DIR/savia-flow.sh" move "alpha" "PBI-001" "review" 2>/dev/null
assert_contains "Status review" "$REPO/projects/alpha/backlog/pbi-001.md" 'status: "review"'

bash "$SCRIPTS_DIR/savia-flow.sh" move "alpha" "PBI-001" "done" 2>/dev/null
assert_ok "Move to done succeeded"
assert_file "Archived PBI" "$REPO/projects/alpha/backlog/archive/pbi-001.md"

# ── Test 5: Log time ───────────────────────────────────────────────
bash "$SCRIPTS_DIR/savia-flow.sh" log-time "alpha" "PBI-002" "4" "Frontend work" 2>/dev/null
assert_ok "Log time succeeded"
MONTH_FILE="$REPO/team/alice/savia-flow/timesheet/$(date +%Y-%m).md"
assert_file "Timesheet file" "$MONTH_FILE"
assert_contains "PBI in timesheet" "$MONTH_FILE" "PBI-002"
assert_contains "Hours in timesheet" "$MONTH_FILE" "hours: 4"

# ── Test 6: Sprint lifecycle ───────────────────────────────────────
bash "$SCRIPTS_DIR/savia-flow.sh" sprint-start "alpha" "sprint-2026-01" "MVP" "2026-03-03" "2026-03-14" 2>/dev/null
assert_ok "Sprint start succeeded"
assert_file "Sprint file" "$REPO/projects/alpha/sprints/sprint-2026-01/sprint.md"
assert_contains "Sprint active" "$REPO/projects/alpha/sprints/sprint-2026-01/sprint.md" 'status: "active"'

bash "$SCRIPTS_DIR/savia-flow.sh" sprint-close "alpha" 2>/dev/null
assert_ok "Sprint close succeeded"
assert_contains "Sprint closed" "$REPO/projects/alpha/sprints/sprint-2026-01/sprint.md" 'status: "closed"'

# ── Test 7: Board rendering ────────────────────────────────────────
OUTPUT=$(bash "$SCRIPTS_DIR/savia-flow.sh" board "alpha" 2>/dev/null)
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "Kanban Board"; then
  PASS=$((PASS + 1)); echo -e "${GREEN}OK${NC} Board rendered"
else FAIL=$((FAIL + 1)); echo -e "${RED}FAIL${NC} Board not rendered"; fi

# ── Test 8: Metrics ─────────────────────────────────────────────────
OUTPUT=$(bash "$SCRIPTS_DIR/savia-flow.sh" metrics "alpha" 2>/dev/null)
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "Story Points"; then
  PASS=$((PASS + 1)); echo -e "${GREEN}OK${NC} Metrics output"
else FAIL=$((FAIL + 1)); echo -e "${RED}FAIL${NC} Metrics missing"; fi

# ── Summary ─────────────────────────────────────────────────────────
export HOME="$ORIG_HOME"
echo ""
echo "--- Results: $PASS/$TOTAL passed, $FAIL failed ---"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
