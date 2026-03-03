#!/bin/bash
# test-savia-flow-tasks.sh — Tests for SDD/tickets/tasks Git-native
# Uso: bash scripts/test-savia-flow-tasks.sh

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
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

cd "$TMPDIR_BASE"
export FLOW_DATA_DIR="$TMPDIR_BASE/.savia-flow-data"
mkdir -p scripts
cp "$SCRIPTS_DIR/savia-flow-tasks.sh" scripts/
cp "$SCRIPTS_DIR/savia-flow-timesheet.sh" scripts/ 2>/dev/null || true

echo "━━━ Test: Savia Flow — Git-Native Tasks ━━━"
echo "Temp: $TMPDIR_BASE"
echo ""

# ── Test 1: Task creation ────────────────────────────────────────────
echo -e "${BLUE}── Task Create ──${NC}"

RESULT=$(bash scripts/savia-flow-tasks.sh create task "Login endpoint" "@alice" "SPR-2026-01" high 2>&1)
assert "Task create succeeds" "echo '$RESULT' | grep -q '✅'"
assert "Task create shows ID" "echo '$RESULT' | grep -q 'TASK-'"

# Find the created task file
TASK_FILE=$(find "$FLOW_DATA_DIR" -name "TASK-*.md" 2>/dev/null | sort | head -1)
assert "Task file exists" "[ -f '$TASK_FILE' ]"
assert "Has frontmatter type" "grep -q 'type: task' '$TASK_FILE'"
assert "Has title" "grep -q 'Login endpoint' '$TASK_FILE'"
assert "Has assigned" "grep -q '@alice' '$TASK_FILE'"
assert "Has status todo" "grep -q 'status: todo' '$TASK_FILE'"
assert "Has priority" "grep -q 'priority: high' '$TASK_FILE'"
assert "Has sprint" "grep -q 'sprint: SPR-2026-01' '$TASK_FILE'"

# Get task ID
TASK_ID=$(grep '^id:' "$TASK_FILE" | awk '{print $2}')
echo -e "${BLUE}ℹ${NC}  Created: $TASK_ID"

# Create second task
RESULT2=$(bash scripts/savia-flow-tasks.sh create bug "CSS broken on mobile" "@bob" "SPR-2026-01" critical 2>&1)
assert "Bug create succeeds" "echo '$RESULT2' | grep -q '✅'"
TASK_FILE2=$(find "$FLOW_DATA_DIR" -name "TASK-*.md" 2>/dev/null | sort | tail -1)
assert "Bug type correct" "grep -q 'type: bug' '$TASK_FILE2'"

# ── Test 2: Task show ────────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Task Show ──${NC}"

RESULT=$(bash scripts/savia-flow-tasks.sh show "$TASK_ID" 2>&1)
assert "Show displays frontmatter" "echo '$RESULT' | grep -q 'id:'"
assert "Show has description section" "echo '$RESULT' | grep -q 'Description'"

# ── Test 3: Task move ────────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Task Move ──${NC}"

RESULT=$(bash scripts/savia-flow-tasks.sh move "$TASK_ID" in-progress 2>&1)
assert "Move to in-progress succeeds" "echo '$RESULT' | grep -q '✅'"

# Find moved file and check status updated
MOVED_FILE=$(find "$FLOW_DATA_DIR" -name "${TASK_ID}.md" 2>/dev/null | head -1)
assert "Moved file still exists" "[ -f '$MOVED_FILE' ]"
assert "Status updated to in-progress" "grep -q 'status: in-progress' '$MOVED_FILE'"

# Move to done
RESULT=$(bash scripts/savia-flow-tasks.sh move "$TASK_ID" done 2>&1)
assert "Move to done succeeds" "echo '$RESULT' | grep -q '✅'"
MOVED_FILE=$(find "$FLOW_DATA_DIR" -name "${TASK_ID}.md" 2>/dev/null | head -1)
assert "Status updated to done" "grep -q 'status: done' '$MOVED_FILE'"

# ── Test 4: Task assign ──────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Task Assign ──${NC}"

TASK_ID2=$(grep '^id:' "$TASK_FILE2" | awk '{print $2}')
RESULT=$(bash scripts/savia-flow-tasks.sh assign "$TASK_ID2" "@carol" 2>&1)
assert "Assign succeeds" "echo '$RESULT' | grep -q '✅'"
ASSIGNED_FILE=$(find "$FLOW_DATA_DIR" -name "${TASK_ID2}.md" 2>/dev/null | head -1)
assert "Assigned updated" "grep -q '@carol' '$ASSIGNED_FILE'"

# ── Test 5: Error handling ───────────────────────────────────────────
echo ""
echo -e "${BLUE}── Error Handling ──${NC}"

RESULT=$(bash scripts/savia-flow-tasks.sh show "TASK-FAKE-9999" 2>&1 || true)
assert "Show nonexistent task fails gracefully" "echo '$RESULT' | grep -q '❌'"

RESULT=$(bash scripts/savia-flow-tasks.sh move "TASK-FAKE-9999" done 2>&1 || true)
assert "Move nonexistent task fails gracefully" "echo '$RESULT' | grep -q '❌'"

RESULT=$(bash scripts/savia-flow-tasks.sh create "" "" "" "" 2>&1 || true)
assert "Create with empty params fails" "echo '$RESULT' | grep -q '❌\|Usage'"

# ── Test 6: Idempotency ─────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Idempotency ──${NC}"

# Moving to same status should not create duplicates
BEFORE_COUNT=$(find "$FLOW_DATA_DIR" -name "${TASK_ID}.md" 2>/dev/null | wc -l)
bash scripts/savia-flow-tasks.sh move "$TASK_ID" done 2>&1 >/dev/null || true
AFTER_COUNT=$(find "$FLOW_DATA_DIR" -name "${TASK_ID}.md" 2>/dev/null | wc -l)
assert "Move same status is idempotent" "[ $BEFORE_COUNT -eq $AFTER_COUNT ]"

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "━━━ Results: $PASS/$TOTAL passed, $FAIL failed ━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
