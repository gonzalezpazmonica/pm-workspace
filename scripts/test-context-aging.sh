#!/usr/bin/env bash
# ── test-context-aging.sh ──────────────────────────────────────────────────
# Tests for v0.43.0: Context Aging + Context Benchmark
# ──────────────────────────────────────────────────────────────────────────────

set -o pipefail

PASS=0
FAIL=0
ERRORS=""

pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }

check_file() {
  [ -f "$1" ] && pass "$2" || fail "$2"
}

check_content() {
  grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"
}

check_executable() {
  [ -x "$1" ] && pass "$2" || fail "$2"
}

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.43.0 — Context Aging & Benchmark"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ── 1. Context Age Command ─────────────────────────────────────────────────

echo "📋 1. Context Age Command"

check_file ".opencode/commands/context-age.md" "context-age.md exists"
check_content ".opencode/commands/context-age.md" "name: context-age" "Has correct frontmatter name"
check_content ".opencode/commands/context-age.md" "context_cost:" "Has context_cost"
check_content ".opencode/commands/context-age.md" "Episódico" "References episodic state"
check_content ".opencode/commands/context-age.md" "Comprimido" "References compressed state"
check_content ".opencode/commands/context-age.md" "Archivable" "References archivable state"
check_content ".opencode/commands/context-age.md" "30 días" "Has 30-day threshold"
check_content ".opencode/commands/context-age.md" "90 días" "Has 90-day threshold"
check_content ".opencode/commands/context-age.md" "/context-age apply" "Has apply subcommand"
check_content ".opencode/commands/context-age.md" "/context-age status" "Has status subcommand"
check_content ".opencode/commands/context-age.md" "decision-log.md sin confirmación" "Safety: no modify without confirmation"
check_content ".opencode/commands/context-age.md" "eliminar decisiones" "Safety: never delete"
check_content ".opencode/commands/context-age.md" "Modo agente" "Has agent mode"
echo ""

# ── 2. Context Benchmark Command ──────────────────────────────────────────

echo "📋 2. Context Benchmark Command"

check_file ".opencode/commands/context-benchmark.md" "context-benchmark.md exists"
check_content ".opencode/commands/context-benchmark.md" "name: context-benchmark" "Has correct frontmatter name"
check_content ".opencode/commands/context-benchmark.md" "context_cost:" "Has context_cost"
check_content ".opencode/commands/context-benchmark.md" "Lost in the Middle" "References U-shape paper"
check_content ".opencode/commands/context-benchmark.md" "Seleccionar suite de test" "Has test selection step"
check_content ".opencode/commands/context-benchmark.md" "Ejecutar tests" "Has execution step"
check_content ".opencode/commands/context-benchmark.md" "Analizar resultados" "Has analysis step"
check_content ".opencode/commands/context-benchmark.md" "/context-benchmark quick" "Has quick subcommand"
check_content ".opencode/commands/context-benchmark.md" "/context-benchmark history" "Has history subcommand"
check_content ".opencode/commands/context-benchmark.md" "modificar ficheros durante el benchmark" "Safety: read-only"
check_content ".opencode/commands/context-benchmark.md" "Modo agente" "Has agent mode"
echo ""

# ── 3. Context Aging Script ────────────────────────────────────────────────

echo "📋 3. Context Aging Script"

check_file "scripts/context-aging.sh" "context-aging.sh exists"
check_executable "scripts/context-aging.sh" "context-aging.sh is executable"
check_content "scripts/context-aging.sh" "do_analyze" "Has analyze function"
check_content "scripts/context-aging.sh" "do_compress" "Has compress function"
check_content "scripts/context-aging.sh" "do_archivable" "Has archivable function"
check_content "scripts/context-aging.sh" "do_archive" "Has archive function"
check_content "scripts/context-aging.sh" "DAYS_COMPRESS=30" "Has 30-day threshold"
check_content "scripts/context-aging.sh" "DAYS_ARCHIVE=90" "Has 90-day threshold"
check_content "scripts/context-aging.sh" "decision-log.md" "References decision-log"
check_content "scripts/context-aging.sh" ".decision-archive" "References archive directory"

# Functional tests
echo ""
echo "  🔧 Functional tests..."

TEMP_DIR=$(mktemp -d)
ORIG_HOME="$HOME"
export PM_WORKSPACE_ROOT="$TEMP_DIR"

# Create a fake decision-log with entries of different ages
mkdir -p "$TEMP_DIR/.decision-archive"
cat > "$TEMP_DIR/decision-log.md" << 'DECLOG'
# Decision Log

## 2026-02-28 — Fresh decision

**Contexto**: Algo reciente
**Decisión**: Hacer X

## 2026-01-15 — Compressible decision

**Contexto**: Algo de hace 45 días
**Decisión**: Hacer Y

## 2025-11-01 — Archivable decision

**Contexto**: Algo de hace 120 días
**Decisión**: Hacer Z
DECLOG

# Test analyze
ANALYZE_OUT=$(bash scripts/context-aging.sh analyze)
if echo "$ANALYZE_OUT" | grep -q "total=3"; then
  pass "Analyze counts 3 total entries"
else
  fail "Analyze total count wrong: $ANALYZE_OUT"
fi

if echo "$ANALYZE_OUT" | grep -q "fresh=1"; then
  pass "Analyze detects 1 fresh entry"
else
  fail "Analyze fresh count wrong: $ANALYZE_OUT"
fi

if echo "$ANALYZE_OUT" | grep -q "compress=1"; then
  pass "Analyze detects 1 compressible entry"
else
  fail "Analyze compress count wrong: $ANALYZE_OUT"
fi

if echo "$ANALYZE_OUT" | grep -q "archive=1"; then
  pass "Analyze detects 1 archivable entry"
else
  fail "Analyze archive count wrong: $ANALYZE_OUT"
fi

# Test archivable listing
ARCHIVABLE_OUT=$(bash scripts/context-aging.sh archivable)
if echo "$ARCHIVABLE_OUT" | grep -q "2025-11-01"; then
  pass "Archivable lists old entry"
else
  fail "Archivable missing old entry"
fi

# Test help
HELP_OUT=$(bash scripts/context-aging.sh help)
if echo "$HELP_OUT" | grep -q "Usage"; then
  pass "Help shows usage"
else
  fail "Help missing usage"
fi

# Cleanup
export HOME="$ORIG_HOME"
unset PM_WORKSPACE_ROOT
rm -rf "$TEMP_DIR"
echo ""

# ── 4. Context Aging Rule ─────────────────────────────────────────────────

echo "📋 4. Context Aging Rule"

check_file "docs/rules/domain/context-aging.md" "context-aging.md rule exists"
check_content "docs/rules/domain/context-aging.md" "episódico" "Rule has episodic category"
check_content "docs/rules/domain/context-aging.md" "comprimido" "Rule has compressed format"
check_content "docs/rules/domain/context-aging.md" "archivarse" "Rule has archival criteria"
check_content "docs/rules/domain/context-aging.md" "migrar a regla de dominio" "Rule has migration criteria"
check_content "docs/rules/domain/context-aging.md" ".decision-archive" "Rule documents archive location"
check_content "docs/rules/domain/context-aging.md" "decision-log.md" "Rule references decision-log"
echo ""

# ── 5. CLAUDE.md Updates ──────────────────────────────────────────────────

echo "📋 5. CLAUDE.md Updates"

# Dynamically check command count
EXPECTED_COUNT=$(ls -1 ".claude/commands"/*.md 2>/dev/null | wc -l)
if grep -q "commands/ ($EXPECTED_COUNT)" "CLAUDE.md" 2>/dev/null; then
  pass "CLAUDE.md has correct dynamic command count"
else
  fail "CLAUDE.md command count mismatch (expected: $EXPECTED_COUNT)"
fi
check_content "CLAUDE.md" "context-age" "CLAUDE.md references /context-age"
check_content "CLAUDE.md" "context-benchmark" "CLAUDE.md references /context-benchmark"
echo ""

# ── 6. README Updates ─────────────────────────────────────────────────────

echo "📋 6. README Updates"

check_content "README.md" "comando" "README.md references version"
check_content "README.md" "context-age" "README.md references /context-age"
check_content "README.md" "context-benchmark" "README.md references /context-benchmark"
check_content "README.md" "envejecimiento semántico" "README.md describes semantic aging"
check_content "README.en.md" "command"
check_content "README.en.md" "context-age" "README.en.md references /context-age"
check_content "README.en.md" "context-benchmark" "README.en.md references /context-benchmark"
echo ""

# ── 7. Context Map Updates ────────────────────────────────────────────────

echo "📋 7. Context Map Updates"

check_content ".claude/profiles/context-map.md" "context-age" "Context-map includes /context-age"
check_content ".claude/profiles/context-map.md" "context-benchmark" "Context-map includes /context-benchmark"
echo ""

# ── 8. CHANGELOG Updates ─────────────────────────────────────────────────

echo "📋 8. CHANGELOG Updates"

check_content "CHANGELOG.md" "0.43.0" "CHANGELOG has v0.43.0 entry"
check_content "CHANGELOG.md" "Context Aging" "CHANGELOG describes context aging"
check_content "CHANGELOG.md" "Verified Positioning" "CHANGELOG describes verified positioning"
check_content "CHANGELOG.md" "compare/v0.42.0...v0.43.0" "CHANGELOG has v0.43.0 compare link"
echo ""

# ── 9. Cross-version Regression ──────────────────────────────────────────

echo "📋 9. Cross-version Regression"

check_file "scripts/context-tracker.sh" "context-tracker.sh still exists"
check_file ".opencode/commands/context-optimize.md" "context-optimize command still exists"
check_file ".opencode/commands/health-dashboard.md" "health-dashboard command still exists"
check_file ".opencode/commands/daily-routine.md" "daily-routine command still exists"
check_file "docs/rules/domain/role-workflows.md" "role-workflows still exists"
check_file "docs/rules/domain/context-tracking.md" "context-tracking rule still exists"
check_file "docs/rules/domain/agent-context-budget.md" "agent-context-budget rule still exists"
echo ""

# ── Summary ────────────────────────────────────────────────────────────────

TOTAL=$((PASS + FAIL))
echo "═══════════════════════════════════════════════════════════════"
echo "  📊 Results: $PASS/$TOTAL passed"
echo "═══════════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "  Failures:"
  echo -e "$ERRORS"
  exit 1
fi

echo ""
echo "  ✅ All tests passed!"
exit 0
