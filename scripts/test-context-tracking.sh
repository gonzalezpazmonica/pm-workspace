#!/usr/bin/env bash
# ── test-context-tracking.sh ───────────────────────────────────────────────
# Tests for v0.40.0: Role workflows, daily routine, health dashboard,
# context tracking, and context optimization
# ──────────────────────────────────────────────────────────────────────────────

set -uo pipefail

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
echo "  🧪 Test Suite: v0.40.0 — Context Tracking & Role Workflows"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ── 1. Role Workflows Rule ─────────────────────────────────────────────────

echo "📋 1. Role Workflows Rule"

check_file ".claude/rules/domain/role-workflows.md" "role-workflows.md exists"
check_content ".claude/rules/domain/role-workflows.md" "PM / Scrum Master" "Contains PM role"
check_content ".claude/rules/domain/role-workflows.md" "Tech Lead" "Contains Tech Lead role"
check_content ".claude/rules/domain/role-workflows.md" "QA Engineer" "Contains QA role"
check_content ".claude/rules/domain/role-workflows.md" "Product Owner" "Contains Product Owner role"
check_content ".claude/rules/domain/role-workflows.md" "Developer" "Contains Developer role"
check_content ".claude/rules/domain/role-workflows.md" "CEO / CTO" "Contains CEO/CTO role"
check_content ".claude/rules/domain/role-workflows.md" "Rutina diaria" "Contains daily routine sections"
check_content ".claude/rules/domain/role-workflows.md" "Ritual semanal" "Contains weekly ritual sections"
check_content ".claude/rules/domain/role-workflows.md" "Métricas clave" "Contains key metrics sections"
check_content ".claude/rules/domain/role-workflows.md" "Alertas personalizadas" "Contains alert sections"
check_content ".claude/rules/domain/role-workflows.md" "Regla de activación" "Contains activation rule"
check_content ".claude/rules/domain/role-workflows.md" "context-map" "References context-map"
check_content ".claude/rules/domain/role-workflows.md" "daily-first" "PM mode is daily-first"
check_content ".claude/rules/domain/role-workflows.md" "code-focused" "Tech Lead mode is code-focused"
check_content ".claude/rules/domain/role-workflows.md" "quality-gate" "QA mode is quality-gate"
check_content ".claude/rules/domain/role-workflows.md" "reporting-focused" "PO mode is reporting-focused"
check_content ".claude/rules/domain/role-workflows.md" "strategic-oversight" "CEO mode is strategic-oversight"
check_content ".claude/rules/domain/role-workflows.md" "NUNCA ejecuta comandos automáticamente" "Contains safety restriction"
echo ""

# ── 2. Daily Routine Command ───────────────────────────────────────────────

echo "📋 2. Daily Routine Command"

check_file ".claude/commands/daily-routine.md" "daily-routine.md exists"
check_content ".claude/commands/daily-routine.md" "name: daily-routine" "Has correct frontmatter name"
check_content ".claude/commands/daily-routine.md" "context_cost:" "Has context_cost"
check_content ".claude/commands/daily-routine.md" "Identificar rol" "Step 1: identify role"
check_content ".claude/commands/daily-routine.md" "Componer rutina" "Step 2: compose routine"
check_content ".claude/commands/daily-routine.md" "Ejecutar bajo demanda" "Step 3: execute on demand"
check_content ".claude/commands/daily-routine.md" "Resumen" "Step 4: summary"
check_content ".claude/commands/daily-routine.md" "role-workflows.md" "References role-workflows"
check_content ".claude/commands/daily-routine.md" "ejecutar comandos sin confirmación" "Safety: no auto-execute"
check_content ".claude/commands/daily-routine.md" "permitir saltar" "Safety: user can skip"
echo ""

# ── 3. Health Dashboard Command ────────────────────────────────────────────

echo "📋 3. Health Dashboard Command"

check_file ".claude/commands/health-dashboard.md" "health-dashboard.md exists"
check_content ".claude/commands/health-dashboard.md" "name: health-dashboard" "Has correct frontmatter name"
check_content ".claude/commands/health-dashboard.md" "context_cost:" "Has context_cost"
check_content ".claude/commands/health-dashboard.md" "Adaptar vista al rol" "Adapts view to role"
check_content ".claude/commands/health-dashboard.md" "Calcular score de salud" "Calculates health score"
check_content ".claude/commands/health-dashboard.md" "Score compuesto" "Uses composite score"
check_content ".claude/commands/health-dashboard.md" "0-100" "Score range 0-100"
check_content ".claude/commands/health-dashboard.md" "Sprint progress" "Has sprint progress dimension"
check_content ".claude/commands/health-dashboard.md" "Code quality" "Has code quality dimension"
check_content ".claude/commands/health-dashboard.md" "Risk exposure" "Has risk exposure dimension"
check_content ".claude/commands/health-dashboard.md" "/health-dashboard all" "Has multi-project subcommand"
check_content ".claude/commands/health-dashboard.md" "/health-dashboard trend" "Has trend subcommand"
check_content ".claude/commands/health-dashboard.md" "inventar datos" "Safety: no fake data"
check_content ".claude/commands/health-dashboard.md" "Modo agente" "Has agent mode"
echo ""

# ── 4. Context Optimize Command ────────────────────────────────────────────

echo "📋 4. Context Optimize Command"

check_file ".claude/commands/context-optimize.md" "context-optimize.md exists"
check_content ".claude/commands/context-optimize.md" "name: context-optimize" "Has correct frontmatter name"
check_content ".claude/commands/context-optimize.md" "context_cost:" "Has context_cost"
check_content ".claude/commands/context-optimize.md" "context-usage.log" "References usage log"
check_content ".claude/commands/context-optimize.md" "Fragmentos más cargados" "Analyzes most loaded fragments"
check_content ".claude/commands/context-optimize.md" "Co-ocurrencias" "Detects co-occurrences"
check_content ".claude/commands/context-optimize.md" "Degradar" "Recommendation: degrade"
check_content ".claude/commands/context-optimize.md" "Promover" "Recommendation: promote"
check_content ".claude/commands/context-optimize.md" "Agrupar" "Recommendation: group"
check_content ".claude/commands/context-optimize.md" "Pre-mapear" "Recommendation: pre-map"
check_content ".claude/commands/context-optimize.md" "/context-optimize stats" "Has stats subcommand"
check_content ".claude/commands/context-optimize.md" "/context-optimize reset" "Has reset subcommand"
check_content ".claude/commands/context-optimize.md" "/context-optimize apply" "Has apply subcommand"
check_content ".claude/commands/context-optimize.md" "modificar el context-map sin confirmación" "Safety: no auto-modify"
check_content ".claude/commands/context-optimize.md" "Modo agente" "Has agent mode"
echo ""

# ── 5. Context Tracker Script ──────────────────────────────────────────────

echo "📋 5. Context Tracker Script"

check_file "scripts/context-tracker.sh" "context-tracker.sh exists"
check_executable "scripts/context-tracker.sh" "context-tracker.sh is executable"
check_content "scripts/context-tracker.sh" "context-usage.log" "References usage log"
check_content "scripts/context-tracker.sh" "do_log" "Has log function"
check_content "scripts/context-tracker.sh" "do_stats" "Has stats function"
check_content "scripts/context-tracker.sh" "do_top_commands" "Has top-commands function"
check_content "scripts/context-tracker.sh" "do_top_fragments" "Has top-fragments function"
check_content "scripts/context-tracker.sh" "do_cooccurrences" "Has co-occurrences function"
check_content "scripts/context-tracker.sh" "do_reset" "Has reset function"
check_content "scripts/context-tracker.sh" "rotate_log" "Has log rotation"
check_content "scripts/context-tracker.sh" "MAX_LOG_SIZE" "Has max size limit"
check_content "scripts/context-tracker.sh" "MAX_LOG_ENTRIES" "Has max entries limit"

# Functional tests
echo ""
echo "  🔧 Functional tests..."

TEMP_DIR=$(mktemp -d)
ORIG_HOME="$HOME"
export HOME="$TEMP_DIR"
mkdir -p "$TEMP_DIR/.pm-workspace"

# Test log subcommand
bash scripts/context-tracker.sh log "sprint-status" "identity.md,workflow.md,projects.md,tone.md" "270"
if [ -f "$TEMP_DIR/.pm-workspace/context-usage.log" ]; then
  pass "Log file created after log command"
else
  fail "Log file NOT created after log command"
fi

# Test log entry format
if grep -q "|sprint-status|identity.md,workflow.md,projects.md,tone.md|270" "$TEMP_DIR/.pm-workspace/context-usage.log" 2>/dev/null; then
  pass "Log entry has correct format (pipe-delimited)"
else
  fail "Log entry format incorrect"
fi

# Add more entries for stats
bash scripts/context-tracker.sh log "pr-pending" "identity.md,workflow.md,tools.md" "190"
bash scripts/context-tracker.sh log "sprint-status" "identity.md,workflow.md,projects.md,tone.md" "270"
bash scripts/context-tracker.sh log "kpi-dashboard" "identity.md,preferences.md,projects.md,tone.md" "260"

# Test stats subcommand
STATS_OUTPUT=$(bash scripts/context-tracker.sh stats)
if echo "$STATS_OUTPUT" | grep -q "entries=4"; then
  pass "Stats shows correct entry count"
else
  fail "Stats entry count incorrect: $STATS_OUTPUT"
fi

if echo "$STATS_OUTPUT" | grep -q "tokens_total=990"; then
  pass "Stats shows correct token total"
else
  fail "Stats token total incorrect: $STATS_OUTPUT"
fi

# Test top-commands
TOP_CMD=$(bash scripts/context-tracker.sh top-commands 3)
if echo "$TOP_CMD" | grep -q "sprint-status"; then
  pass "Top commands includes sprint-status"
else
  fail "Top commands missing sprint-status"
fi

# Test top-fragments
TOP_FRAG=$(bash scripts/context-tracker.sh top-fragments 3)
if echo "$TOP_FRAG" | grep -q "identity.md"; then
  pass "Top fragments includes identity.md"
else
  fail "Top fragments missing identity.md"
fi

# Test reset with backup
bash scripts/context-tracker.sh reset > /dev/null
if [ -f "$TEMP_DIR/.pm-workspace/context-usage.log" ] && [ ! -s "$TEMP_DIR/.pm-workspace/context-usage.log" ]; then
  pass "Reset clears the log"
else
  fail "Reset did not clear the log"
fi

if ls "$TEMP_DIR/.pm-workspace/context-usage.log.bak."* 1>/dev/null 2>&1; then
  pass "Reset creates backup"
else
  fail "Reset did not create backup"
fi

# Test help
HELP_OUTPUT=$(bash scripts/context-tracker.sh help)
if echo "$HELP_OUTPUT" | grep -q "Usage"; then
  pass "Help shows usage"
else
  fail "Help does not show usage"
fi

# Cleanup temp
export HOME="$ORIG_HOME"
rm -rf "$TEMP_DIR"
echo ""

# ── 6. Context Tracking Rule ──────────────────────────────────────────────

echo "📋 6. Context Tracking Rule"

check_file ".claude/rules/domain/context-tracking.md" "context-tracking.md exists"
check_content ".claude/rules/domain/context-tracking.md" "Qué se registra" "Documents what is tracked"
check_content ".claude/rules/domain/context-tracking.md" "Qué NO se registra" "Documents what is NOT tracked"
check_content ".claude/rules/domain/context-tracking.md" "Privacidad" "Has privacy section"
check_content ".claude/rules/domain/context-tracking.md" "context-usage.log" "References log file"
check_content ".claude/rules/domain/context-tracking.md" "Estimación de tokens" "Has token estimation"
check_content ".claude/rules/domain/context-tracking.md" "datos de usuario" "Privacy: no user content"
echo ""


# ── 7. Context Map Updates ─────────────────────────────────────────────────

echo "📋 7. Context Map Updates"

check_content ".claude/profiles/context-map.md" "Daily Routine & Health" "Context-map has new group"
check_content ".claude/profiles/context-map.md" "daily-routine" "Context-map includes /daily-routine"
check_content ".claude/profiles/context-map.md" "health-dashboard" "Context-map includes /health-dashboard"
check_content ".claude/profiles/context-map.md" "context-optimize" "Context-map includes /context-optimize"
echo ""

# ── 8. CLAUDE.md Updates ──────────────────────────────────────────────────

echo "📋 8. CLAUDE.md Updates"

check_content "CLAUDE.md" "144 slash commands" "CLAUDE.md shows 144 commands"
check_content "CLAUDE.md" "daily-routine" "CLAUDE.md references /daily-routine"
check_content "CLAUDE.md" "health-dashboard" "CLAUDE.md references /health-dashboard"
check_content "CLAUDE.md" "context-optimize" "CLAUDE.md references /context-optimize"
echo ""

# ── 9. README Updates ─────────────────────────────────────────────────────

echo "📋 9. README Updates"

check_content "README.md" "144 comandos" "README.md shows 144 commands"
check_content "README.md" "Rutina diaria adaptativa" "README.md has daily routine section"
check_content "README.md" "Optimización de contexto" "README.md has context optimization section"
check_content "README.md" "/daily-routine" "README.md command reference includes /daily-routine"
check_content "README.md" "/health-dashboard" "README.md command reference includes /health-dashboard"
check_content "README.md" "/context-optimize" "README.md command reference includes /context-optimize"
check_content "README.en.md" "144 commands" "README.en.md shows 144 commands"
check_content "README.en.md" "Adaptive daily routine" "README.en.md has daily routine section"
check_content "README.en.md" "Context optimization" "README.en.md has context optimization section"
echo ""

# ── 10. CHANGELOG Updates ─────────────────────────────────────────────────

echo "📋 10. CHANGELOG Updates"

check_content "CHANGELOG.md" "0.40.0" "CHANGELOG has v0.40.0 entry"
check_content "CHANGELOG.md" "Role-Adaptive Daily Routines" "CHANGELOG describes role feature"
check_content "CHANGELOG.md" "Health Dashboard" "CHANGELOG describes health dashboard"
check_content "CHANGELOG.md" "Context Usage Optimization" "CHANGELOG describes context tracking"
echo ""

# ── 11. Cross-version Regression ──────────────────────────────────────────

echo "📋 11. Cross-version Regression"

# Verify previous features still exist
check_file "scripts/contribute.sh" "contribute.sh still exists"
check_file "scripts/backup.sh" "backup.sh still exists"
check_file "scripts/review-community.sh" "review-community.sh still exists"
check_file ".claude/commands/contribute.md" "contribute command still exists"
check_file ".claude/commands/feedback.md" "feedback command still exists"
check_file ".claude/commands/backup.md" "backup command still exists"
check_file ".claude/rules/domain/community-protocol.md" "community protocol still exists"
check_file ".claude/rules/domain/vertical-detection.md" "vertical detection still exists"
check_file ".claude/rules/domain/backup-protocol.md" "backup protocol still exists"
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
