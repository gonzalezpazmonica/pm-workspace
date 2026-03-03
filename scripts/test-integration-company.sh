#!/bin/bash
# test-integration-company.sh — Integration orchestrator for Savia v3
# Runs all test suites, aggregates results, verifies remote branches

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
TOTAL_PASS=0; TOTAL_FAIL=0; TOTAL_TESTS=0
SUITE_RESULTS=()
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

TMPDIR_BASE=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Company Savia — Integration Tests (Branch-Based)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Helper: run a suite and track result ─────────────────────────────
run_suite() {
  local name="$1" script="$2"
  echo "── Step: $name ──"
  local exit_code=0
  bash "$script" 2>&1 || exit_code=$?
  if [ "$exit_code" -eq 0 ]; then
    SUITE_RESULTS+=("${GREEN}✅ $name${NC}")
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    SUITE_RESULTS+=("${RED}❌ $name${NC}")
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  echo ""
}

# ── Step 1: Unit test suites ──────────────────────────────────────────
echo -e "${BLUE}══ Unit Tests ══${NC}"
run_suite "test-savia-flow.sh"       "$SCRIPTS_DIR/test-savia-flow.sh"
run_suite "test-savia-index.sh"      "$SCRIPTS_DIR/test-savia-index.sh"

# ── Step 2: Smoke tests — verify branch structure ───────────────────
echo -e "${BLUE}══ Smoke Tests ══${NC}"

# Create a test repo with branches
TEST_REPO="$TMPDIR_BASE/smoke-repo"
TEST_CLONE="$TMPDIR_BASE/smoke-clone"
git init --bare "$TEST_REPO" >/dev/null 2>&1
git clone "$TEST_REPO" "$TEST_CLONE" >/dev/null 2>&1
cd "$TEST_CLONE"
echo "# Smoke" > README.md && git add . && git commit -m "init" >/dev/null 2>&1
git push origin main >/dev/null 2>&1
bash "$SCRIPTS_DIR/savia-branch.sh" ensure-orphan "$TEST_CLONE" "team/backend" "init: team" 2>/dev/null
bash "$SCRIPTS_DIR/savia-branch.sh" ensure-orphan "$TEST_CLONE" "user/alice" "init: user" 2>/dev/null
git -C "$TEST_CLONE" fetch --all >/dev/null 2>&1

SMOKE_PASS=0; SMOKE_FAIL=0; SMOKE_TOTAL=0

smoke_assert() {
  SMOKE_TOTAL=$((SMOKE_TOTAL + 1))
  if eval "$2" >/dev/null 2>&1; then
    SMOKE_PASS=$((SMOKE_PASS + 1))
    echo -e "${GREEN}✅ $1${NC}"
  else
    SMOKE_FAIL=$((SMOKE_FAIL + 1))
    echo -e "${RED}❌ $1${NC}"
  fi
}

smoke_assert "main branch exists"       "git -C '$TEST_CLONE' rev-parse origin/main >/dev/null 2>&1"
smoke_assert "team/backend branch exists" "git -C '$TEST_CLONE' rev-parse origin/team/backend >/dev/null 2>&1"
smoke_assert "user/alice branch exists"   "git -C '$TEST_CLONE' rev-parse origin/user/alice >/dev/null 2>&1"

echo ""
echo "Smoke: $SMOKE_PASS/$SMOKE_TOTAL passed, $SMOKE_FAIL failed"

TOTAL_PASS=$((TOTAL_PASS + SMOKE_PASS))
TOTAL_FAIL=$((TOTAL_FAIL + SMOKE_FAIL))
TOTAL_TESTS=$((TOTAL_TESTS + SMOKE_TOTAL))

if [ "$SMOKE_FAIL" -eq 0 ]; then
  SUITE_RESULTS+=("${GREEN}✅ Smoke Tests ($SMOKE_PASS/$SMOKE_TOTAL)${NC}")
else
  SUITE_RESULTS+=("${RED}❌ Smoke Tests ($SMOKE_PASS/$SMOKE_TOTAL)${NC}")
fi
echo ""

# ── Summary ──────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Integration Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for result in "${SUITE_RESULTS[@]}"; do
  echo -e "  $result"
done
echo ""
echo "Total suites: $TOTAL_TESTS"
echo "Passed: $TOTAL_PASS | Failed: $TOTAL_FAIL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ "$TOTAL_FAIL" -eq 0 ] && exit 0 || exit 1
