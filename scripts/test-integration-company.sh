#!/bin/bash
# test-integration-company.sh — Integration tests against a real Company Savia repo
# Uso: bash scripts/test-integration-company.sh
#
# Clones AIrquiTech, runs all 3 test suites, adds smoke tests, aggregates results.

set -euo pipefail

# ── Test harness ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
TOTAL_PASS=0; TOTAL_FAIL=0; TOTAL_TESTS=0
SUITE_RESULTS=()
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/savia-compat.sh"

TMPDIR_BASE=$(mktemp -d)
CLONE_DIR="$TMPDIR_BASE/airquitech"
REMOTE_URL="https://github.com/gonzalezpazmonica/AIrquiTech"

cleanup() {
  rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Company Savia — Integration Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Temp dir:  $TMPDIR_BASE"
echo "Remote:    $REMOTE_URL"
echo ""

# ── Step 1: Clone real repo ─────────────────────────────────────────
echo "── Step 1: Clone repo ──"
if git clone --depth 1 "$REMOTE_URL" "$CLONE_DIR" 2>/dev/null; then
  echo -e "${GREEN}✅ Cloned AIrquiTech successfully${NC}"
else
  echo -e "${RED}❌ Failed to clone AIrquiTech — aborting${NC}"
  exit 1
fi
echo ""

# ── Helper: run a suite and capture result ──────────────────────────
run_suite() {
  local name="$1"
  local script="$2"

  echo "── Step: $name ──"
  local exit_code=0
  bash "$script" 2>&1 || exit_code=$?

  if [ "$exit_code" -eq 0 ]; then
    SUITE_RESULTS+=("${GREEN}✅ $name${NC}")
  else
    SUITE_RESULTS+=("${RED}❌ $name${NC}")
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  echo ""
}

# ── Step 2: Run unit test suites ────────────────────────────────────
run_suite "test-company-repo.sh"    "$SCRIPTS_DIR/test-company-repo.sh"
run_suite "test-savia-messaging.sh" "$SCRIPTS_DIR/test-savia-messaging.sh"
run_suite "test-savia-crypto.sh"    "$SCRIPTS_DIR/test-savia-crypto.sh"

# ── Step 3: Smoke tests against cloned repo ─────────────────────────
echo "── Step: Smoke Tests (repo structure) ──"
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

smoke_assert "company/ dir exists"           "[ -d '$CLONE_DIR/company' ]"
smoke_assert "team/ dir exists"              "[ -d '$CLONE_DIR/team' ]"
smoke_assert "directory.md exists"           "[ -f '$CLONE_DIR/directory.md' ]"
smoke_assert "company/identity.md exists"    "[ -f '$CLONE_DIR/company/identity.md' ]"
smoke_assert "CODEOWNERS exists"             "[ -f '$CLONE_DIR/CODEOWNERS' ]"
smoke_assert "company-inbox/ dir exists"     "[ -d '$CLONE_DIR/company-inbox' ]"
smoke_assert "README.md exists"              "[ -f '$CLONE_DIR/README.md' ]"

# Verify directory.md is parseable (has @handle lines)
smoke_assert "directory.md has @handle entries" \
  "grep -qE '^[|].*@[a-zA-Z0-9_-]+' '$CLONE_DIR/directory.md'"

# Verify privacy-check passes on the cloned repo (no secrets in tree)
smoke_assert "privacy-check passes on repo" \
  "bash '$SCRIPTS_DIR/privacy-check-company.sh' '$CLONE_DIR'"

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

# ── Summary ─────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Integration Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for result in "${SUITE_RESULTS[@]}"; do
  echo -e "  $result"
done
echo ""
echo "Smoke tests: $SMOKE_PASS passed, $SMOKE_FAIL failed"
echo "Suite failures: $TOTAL_FAIL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ "$TOTAL_FAIL" -eq 0 ] && exit 0 || exit 1
