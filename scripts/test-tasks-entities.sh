#!/usr/bin/env bash
# test-tasks-entities.sh — Validate Tasks as First-Class Entities
# ── Phase 1 spec compliance checks ──────────────────────────────

set -euo pipefail

BACKLOG_DIR="projects/savia-web/backlog"
TASKS_DIR="$BACKLOG_DIR/tasks"
CONFIG_FILE="$BACKLOG_DIR/_config.yaml"
SAMPLE_TASK="$TASKS_DIR/TASK-004-001-sample-task.md"
TEMPLATE_FILE="$TASKS_DIR/_template.md"
PBI_004="$BACKLOG_DIR/pbi/PBI-004-test-item.md"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=========================================="
echo "  Tasks as First-Class Entities — Tests"
echo "=========================================="
echo ""

# 1. tasks/ directory exists
echo "[1] backlog/tasks/ directory exists"
if [ -d "$TASKS_DIR" ]; then
  pass "Directory exists"
else
  fail "Directory $TASKS_DIR not found"
fi

# 2. _config.yaml has tasks: section
echo "[2] _config.yaml has tasks: section"
if grep -q "^tasks:" "$CONFIG_FILE" 2>/dev/null; then
  pass "tasks: section found"
else
  fail "tasks: section missing in $CONFIG_FILE"
fi

# 3. Sample task has valid frontmatter fields
echo "[3] Sample task has required frontmatter"
if [ -f "$SAMPLE_TASK" ]; then
  missing=""
  for field in "^id:" "^parent_pbi:" "^type:" "^state:"; do
    if ! grep -q "$field" "$SAMPLE_TASK"; then
      missing="$missing ${field#^}"
    fi
  done
  if [ -z "$missing" ]; then
    pass "All required frontmatter fields present"
  else
    fail "Missing frontmatter:$missing"
  fi
else
  fail "Sample task file not found: $SAMPLE_TASK"
fi

# 4. Sample task has Registro de Horas section
echo "[4] Sample task has Registro de Horas section"
if grep -q "## Registro de Horas" "$SAMPLE_TASK" 2>/dev/null; then
  pass "Registro de Horas section found"
else
  fail "Registro de Horas section missing"
fi

# 5. Sample task has Historial section
echo "[5] Sample task has Historial section"
if grep -q "## Historial" "$SAMPLE_TASK" 2>/dev/null; then
  pass "Historial section found"
else
  fail "Historial section missing"
fi

# 6. PBI-004 Tasks section has linked format
echo "[6] PBI-004 Tasks section uses linked format"
if grep -q '](../tasks/' "$PBI_004" 2>/dev/null; then
  pass "Linked task references found in PBI-004"
else
  fail "No linked task references in PBI-004"
fi

# 7. Template file exists
echo "[7] Template file exists"
if [ -f "$TEMPLATE_FILE" ]; then
  pass "Template file found"
else
  fail "Template file not found: $TEMPLATE_FILE"
fi

# 8. All task files <= 150 lines
echo "[8] All task files <= 150 lines"
oversized=""
for f in "$TASKS_DIR"/TASK-*.md "$TEMPLATE_FILE"; do
  [ -f "$f" ] || continue
  lines=$(wc -l < "$f")
  if [ "$lines" -gt 150 ]; then
    oversized="$oversized $(basename "$f")($lines)"
  fi
done
if [ -z "$oversized" ]; then
  pass "All task files within 150-line limit"
else
  fail "Oversized files:$oversized"
fi

# Summary
echo ""
echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
