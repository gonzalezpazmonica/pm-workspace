#!/usr/bin/env bash
# ── test-hub-audit.sh ─────────────────────────────────────────────────────
# Tests for v0.44.0: Semantic Hub Topology
# ──────────────────────────────────────────────────────────────────────────

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

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.44.0 — Semantic Hub Topology"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ── 1. Hub Audit Command ─────────────────────────────────────────────────

echo "📋 1. Hub Audit Command"

check_file ".opencode/commands/hub-audit.md" "hub-audit.md exists"
check_content ".opencode/commands/hub-audit.md" "name: hub-audit" "Has correct frontmatter name"
check_content ".opencode/commands/hub-audit.md" "context_cost:" "Has context_cost"
check_content ".opencode/commands/hub-audit.md" "Escanear referencias" "Step 1: scan references"
check_content ".opencode/commands/hub-audit.md" "Clasificar" "Step 2: classify"
check_content ".opencode/commands/hub-audit.md" "Comparar con índice" "Step 3: compare with index"
check_content ".opencode/commands/hub-audit.md" "Mostrar informe" "Step 4: show report"
check_content ".opencode/commands/hub-audit.md" "Actualizar índice" "Step 5: update index"
check_content ".opencode/commands/hub-audit.md" "/hub-audit quick" "Has quick subcommand"
check_content ".opencode/commands/hub-audit.md" "/hub-audit update" "Has update subcommand"
check_content ".opencode/commands/hub-audit.md" "modificar reglas de dominio automáticamente" "Safety: no auto-modify rules"
check_content ".opencode/commands/hub-audit.md" "eliminar reglas dormant sin confirmación" "Safety: no delete without confirmation"
check_content ".opencode/commands/hub-audit.md" "semantic-hub-index.md" "References semantic-hub-index"
check_content ".opencode/commands/hub-audit.md" "Modo agente" "Has agent mode"
echo ""

# ── 2. Semantic Hub Index ─────────────────────────────────────────────────

echo "📋 2. Semantic Hub Index"

check_file "docs/rules/domain/semantic-hub-index.md" "semantic-hub-index.md exists"
check_content "docs/rules/domain/semantic-hub-index.md" "name: semantic-hub-index" "Has correct frontmatter name"
check_content "docs/rules/domain/semantic-hub-index.md" "Hub" "Documents hub concept"
check_content "docs/rules/domain/semantic-hub-index.md" "Near-Hub" "Documents near-hub tier"
check_content "docs/rules/domain/semantic-hub-index.md" "Paired" "Documents paired tier"
check_content "docs/rules/domain/semantic-hub-index.md" "dormant" "Documents dormant tier"
check_content "docs/rules/domain/semantic-hub-index.md" "messaging-config.md" "Identifies messaging-config as hub"
check_content "docs/rules/domain/semantic-hub-index.md" "azure-repos-config.md" "Identifies azure-repos-config as near-hub"
check_content "docs/rules/domain/semantic-hub-index.md" "role-workflows.md" "Identifies role-workflows as near-hub"
check_content "docs/rules/domain/semantic-hub-index.md" "Métricas de red" "Has network metrics section"
check_content "docs/rules/domain/semantic-hub-index.md" "Topología actual" "Has topology analysis"
check_content "docs/rules/domain/semantic-hub-index.md" "Recomendaciones" "Has recommendations section"
check_content "docs/rules/domain/semantic-hub-index.md" "estrellas aisladas" "Describes star topology"
check_content "docs/rules/domain/semantic-hub-index.md" "mundo pequeño" "References small-world target"
echo ""

# ── 3. CLAUDE.md Updates ──────────────────────────────────────────────────

echo "📋 3. CLAUDE.md Updates"

# Dynamically check command count
EXPECTED_COUNT=$(ls -1 ".claude/commands"/*.md 2>/dev/null | wc -l)
if grep -q "commands/ ($EXPECTED_COUNT)" "CLAUDE.md" 2>/dev/null; then
  pass "CLAUDE.md has correct dynamic command count"
else
  fail "CLAUDE.md command count mismatch (expected: $EXPECTED_COUNT)"
fi
check_content "CLAUDE.md" "hub-audit" "CLAUDE.md references /hub-audit"
echo ""

# ── 4. README Updates ─────────────────────────────────────────────────────

echo "📋 4. README Updates"

check_content "README.md" "comando" "README.md references version"
check_content "README.md" "hub-audit" "README.md references /hub-audit"
check_content "README.md" "topología" "README.md describes topology"
check_content "README.en.md" "command"
check_content "README.en.md" "hub-audit" "README.en.md references /hub-audit"
check_content "README.en.md" "topology" "README.en.md describes topology"
echo ""

# ── 5. Context Map Updates ────────────────────────────────────────────────

echo "📋 5. Context Map Updates"

check_content ".claude/profiles/context-map.md" "hub-audit" "Context-map includes /hub-audit"
echo ""

# ── 6. CHANGELOG Updates ─────────────────────────────────────────────────

echo "📋 6. CHANGELOG Updates"

check_content "CHANGELOG.md" "0.44.0" "CHANGELOG has v0.44.0 entry"
check_content "CHANGELOG.md" "Semantic Hub" "CHANGELOG describes semantic hub"
check_content "CHANGELOG.md" "hub-audit" "CHANGELOG references hub-audit"
check_content "CHANGELOG.md" "compare/v0.43.0...v0.44.0" "CHANGELOG has v0.44.0 compare link"
echo ""

# ── 7. Cross-version Regression ──────────────────────────────────────────

echo "📋 7. Cross-version Regression"

check_file "scripts/context-aging.sh" "context-aging.sh still exists"
check_file "scripts/context-tracker.sh" "context-tracker.sh still exists"
check_file ".opencode/commands/context-age.md" "context-age command still exists"
check_file ".opencode/commands/context-benchmark.md" "context-benchmark command still exists"
check_file ".opencode/commands/context-optimize.md" "context-optimize command still exists"
check_file ".opencode/commands/health-dashboard.md" "health-dashboard command still exists"
check_file ".opencode/commands/daily-routine.md" "daily-routine command still exists"
check_file "docs/rules/domain/context-aging.md" "context-aging rule still exists"
check_file "docs/rules/domain/context-tracking.md" "context-tracking rule still exists"
check_file "docs/rules/domain/agent-context-budget.md" "agent-context-budget rule still exists"
check_file "docs/rules/domain/role-workflows.md" "role-workflows rule still exists"
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
