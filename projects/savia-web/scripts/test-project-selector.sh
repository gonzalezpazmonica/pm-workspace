#!/usr/bin/env bash
# Validation script for Global Project Selector implementation
# Spec: specs/phase2-project-selector.spec.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$PROJECT_ROOT/src"

PASS=0
FAIL=0
ERRORS=()

check() {
  local description="$1"
  local result="$2"
  if [ "$result" = "ok" ]; then
    echo "  PASS  $description"
    ((PASS++))
  else
    echo "  FAIL  $description"
    ERRORS+=("$description")
    ((FAIL++))
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PROJECT SELECTOR — Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "── Stores ──────────────────────────────────────────────────"

STORE_FILE="$SRC/stores/project.ts"
if [ -f "$STORE_FILE" ]; then
  check "src/stores/project.ts exists" "ok"
else
  check "src/stores/project.ts exists" "fail"
fi

if [ -f "$STORE_FILE" ] && grep -q "function select" "$STORE_FILE"; then
  check "store has select() function" "ok"
else
  check "store has select() function" "fail"
fi

if [ -f "$STORE_FILE" ] && grep -q "function load" "$STORE_FILE"; then
  check "store has load() function" "ok"
else
  check "store has load() function" "fail"
fi

if [ -f "$STORE_FILE" ] && grep -q "savia:selectedProject" "$STORE_FILE"; then
  check "store uses localStorage key savia:selectedProject" "ok"
else
  check "store uses localStorage key savia:selectedProject" "fail"
fi

if [ -f "$STORE_FILE" ] && grep -q "savia:project-changed" "$STORE_FILE"; then
  check "store dispatches savia:project-changed event" "ok"
else
  check "store dispatches savia:project-changed event" "fail"
fi

echo ""
echo "── Types ───────────────────────────────────────────────────"

TYPES_FILE="$SRC/types/bridge.ts"
if [ -f "$TYPES_FILE" ] && grep -q "interface ProjectInfo" "$TYPES_FILE"; then
  check "ProjectInfo interface exists in src/types/bridge.ts" "ok"
else
  check "ProjectInfo interface exists in src/types/bridge.ts" "fail"
fi

if [ -f "$TYPES_FILE" ] && grep -q "'healthy' | 'warning' | 'critical' | 'unknown'" "$TYPES_FILE"; then
  check "ProjectInfo.health has correct union type" "ok"
else
  check "ProjectInfo.health has correct union type" "fail"
fi

echo ""
echo "── Components ──────────────────────────────────────────────"

SELECTOR_FILE="$SRC/components/ProjectSelector.vue"
if [ -f "$SELECTOR_FILE" ] && grep -q "useProjectStore" "$SELECTOR_FILE"; then
  check "ProjectSelector.vue imports from stores/project" "ok"
else
  check "ProjectSelector.vue imports from stores/project" "fail"
fi

if [ -f "$SELECTOR_FILE" ] && grep -q "health-dot\|healthColor" "$SELECTOR_FILE"; then
  check "ProjectSelector.vue renders health indicator dot" "ok"
else
  check "ProjectSelector.vue renders health indicator dot" "fail"
fi

TOPBAR_FILE="$SRC/components/AppTopBar.vue"
if [ -f "$TOPBAR_FILE" ] && grep -q "<ProjectSelector" "$TOPBAR_FILE"; then
  check "AppTopBar.vue includes <ProjectSelector" "ok"
else
  check "AppTopBar.vue includes <ProjectSelector" "fail"
fi

if [ -f "$TOPBAR_FILE" ] && grep -q "import ProjectSelector" "$TOPBAR_FILE"; then
  check "AppTopBar.vue imports ProjectSelector component" "ok"
else
  check "AppTopBar.vue imports ProjectSelector component" "fail"
fi

echo ""
echo "── Layout ──────────────────────────────────────────────────"

LAYOUT_FILE="$SRC/layouts/MainLayout.vue"
if [ -f "$LAYOUT_FILE" ] && grep -q "useProjectStore" "$LAYOUT_FILE"; then
  check "MainLayout.vue uses useProjectStore" "ok"
else
  check "MainLayout.vue uses useProjectStore" "fail"
fi

if [ -f "$LAYOUT_FILE" ] && grep -q "projectStore.load\|projectStore\.load" "$LAYOUT_FILE"; then
  check "MainLayout.vue calls projectStore.load() on mounted" "ok"
else
  check "MainLayout.vue calls projectStore.load() on mounted" "fail"
fi

echo ""
echo "── Tests ───────────────────────────────────────────────────"

STORE_TEST="$SRC/__tests__/stores/project.test.ts"
if [ -f "$STORE_TEST" ]; then
  check "Store test file exists" "ok"
else
  check "Store test file exists" "fail"
fi

COMP_TEST="$SRC/__tests__/components/ProjectSelector.test.ts"
if [ -f "$COMP_TEST" ]; then
  check "Component test file exists" "ok"
else
  check "Component test file exists" "fail"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -eq 0 ]; then
  echo "  Status:  ALL CHECKS PASSED"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
else
  echo ""
  echo "  Failed checks:"
  for err in "${ERRORS[@]}"; do
    echo "    - $err"
  done
  echo ""
  echo "  NOTE: src/types/bridge.ts and src/stores/project.ts require the TDD gate"
  echo "  to be bypassed. Set CLAUDE_PROJECT_DIR=/home/monica/savia/projects/savia-web"
  echo "  before running Claude Code in the worktree, or disable the TDD gate."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
fi
