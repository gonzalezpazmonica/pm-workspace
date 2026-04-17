#!/bin/bash
# test-savia-school.sh — Tests for Savia School educational vertical
# Uso: bash scripts/test-savia-school.sh
#
# Tests: setup, enroll, project, submit, progress, export, forget, security.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0; TOTAL=0
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

assert() {
  TOTAL=$((TOTAL + 1))
  if eval "$2" >/dev/null 2>&1; then PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1${NC}"; fi
}

assert_not() {
  TOTAL=$((TOTAL + 1))
  if ! eval "$2" >/dev/null 2>&1; then PASS=$((PASS + 1)); echo -e "${GREEN}✅ $1${NC}"
  else FAIL=$((FAIL + 1)); echo -e "${RED}❌ $1${NC}"; fi
}

# ── Setup ────────────────────────────────────────────────────────────
TMPDIR_BASE=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

cd "$TMPDIR_BASE"
mkdir -p scripts
cp "$SCRIPTS_DIR/savia-school.sh" scripts/
cp "$SCRIPTS_DIR/savia-school-security.sh" scripts/ 2>/dev/null || true

echo "━━━ Test: Savia School ━━━"
echo "Temp: $TMPDIR_BASE"
echo ""

# ── Test 1: School setup ─────────────────────────────────────────────
echo -e "${BLUE}── Setup ──${NC}"

RESULT=$(bash scripts/savia-school.sh setup "IES Ejemplo" "3ESO" "Tecnologia" 2>&1)
assert "Setup command succeeds" "echo '$RESULT' | grep -q '✅'"
assert "School root created" "[ -d 'school-savia' ]"
assert "Config file created" "[ -f 'school-savia/.school-config.md' ]"
assert "Classroom dir created" "[ -d 'school-savia/classroom' ]"
assert "Teacher dir created" "[ -d 'school-savia/teacher' ]"
assert "Evaluations dir created" "[ -d 'school-savia/teacher/evaluations' ]"
assert "Rubrics dir created" "[ -d 'school-savia/teacher/rubrics' ]"
assert "Templates dir created" "[ -d 'school-savia/templates' ]"

# Check config content
assert "Config has school name" "grep -q 'IES Ejemplo' school-savia/.school-config.md"
assert "Config has GDPR enabled" "grep -q 'gdpr_enabled: true' school-savia/.school-config.md"

# ── Test 2: Enrollment ───────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Enroll ──${NC}"

RESULT=$(bash scripts/savia-school.sh enroll "alumno-01" 2>&1)
assert "Enroll command succeeds" "echo '$RESULT' | grep -q '✅'"
assert "Student dir created" "[ -d 'school-savia/classroom/alumno-01' ]"
assert "Projects dir exists" "[ -d 'school-savia/classroom/alumno-01/projects' ]"
assert "Progress file exists" "[ -f 'school-savia/classroom/alumno-01/progress.md' ]"
assert "Portfolio file exists" "[ -f 'school-savia/classroom/alumno-01/portfolio.md' ]"

# Enroll second student
bash scripts/savia-school.sh enroll "alumno-02" 2>&1 >/dev/null
assert "Second student enrolled" "[ -d 'school-savia/classroom/alumno-02' ]"

# ── Test 3: No PII check ────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Privacy (No PII) ──${NC}"

# Verify no real names in directory
assert_not "No real names in classroom" "find school-savia/classroom -type f | xargs grep -l 'María\|Juan\|Pedro'"
assert "Only alias in progress" "grep -q 'alumno-01' school-savia/classroom/alumno-01/progress.md"

# ── Test 4: Project creation ─────────────────────────────────────────
echo ""
echo -e "${BLUE}── Project ──${NC}"

RESULT=$(bash scripts/savia-school.sh project-create "alumno-01" "mi-web" 2>&1)
assert "Project create succeeds" "echo '$RESULT' | grep -q '✅'"
assert "Project dir exists" "[ -d 'school-savia/classroom/alumno-01/projects/mi-web' ]"
assert "README.md created" "[ -f 'school-savia/classroom/alumno-01/projects/mi-web/README.md' ]"

# ── Test 5: Submit ───────────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Submit ──${NC}"

RESULT=$(bash scripts/savia-school.sh submit "alumno-01" "mi-web" 2>&1)
assert "Submit command succeeds" "echo '$RESULT' | grep -q '✅'"
assert "Submitted marker exists" "[ -f 'school-savia/classroom/alumno-01/projects/mi-web/.submitted' ]"

# Verify timestamp in submitted marker
SUBMIT_TS=$(cat school-savia/classroom/alumno-01/projects/mi-web/.submitted)
assert "Submit has timestamp" "[ ${#SUBMIT_TS} -gt 10 ]"

# ── Test 6: Progress ─────────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Progress ──${NC}"

RESULT=$(bash scripts/savia-school.sh progress "alumno-01" 2>&1)
assert "Progress command succeeds" "echo '$RESULT' | grep -q 'alumno-01'"

# ── Test 7: GDPR Export ──────────────────────────────────────────────
echo ""
echo -e "${BLUE}── GDPR Export ──${NC}"

mkdir -p output
RESULT=$(bash scripts/savia-school.sh export "alumno-01" 2>&1)
assert "Export command succeeds" "echo '$RESULT' | grep -q '✅'"
assert "Export file created" "ls output/gdpr-export-alumno-01-*.tar.gz 2>/dev/null | head -1"

# ── Test 8: GDPR Forget (Right to Erasure) ───────────────────────────
echo ""
echo -e "${BLUE}── GDPR Forget ──${NC}"

RESULT=$(bash scripts/savia-school.sh forget "alumno-02" 2>&1)
assert "Forget command succeeds" "echo '$RESULT' | grep -q '✅'"
assert_not "Student dir removed" "[ -d 'school-savia/classroom/alumno-02' ]"
assert_not "Evaluations removed" "[ -d 'school-savia/teacher/evaluations/alumno-02' ]"

# Verify alumno-01 still exists (isolation)
assert "Other student unaffected" "[ -d 'school-savia/classroom/alumno-01' ]"

# ── Test 9: Idempotency ─────────────────────────────────────────────
echo ""
echo -e "${BLUE}── Idempotency ──${NC}"

bash scripts/savia-school.sh setup "IES Ejemplo" "3ESO" "Tecnologia" 2>&1 >/dev/null
assert "Setup idempotent — dirs still exist" "[ -d 'school-savia/classroom' ]"
assert "Setup idempotent — config preserved" "grep -q 'IES Ejemplo' school-savia/.school-config.md"

bash scripts/savia-school.sh enroll "alumno-01" 2>&1 >/dev/null
assert "Re-enroll idempotent — dir still exists" "[ -d 'school-savia/classroom/alumno-01' ]"

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "━━━ Results: $PASS/$TOTAL passed, $FAIL failed ━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
