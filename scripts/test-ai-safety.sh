#!/usr/bin/env bash
# ── test-ai-safety.sh ────────────────────────────────────────────────────────
# Tests for v0.58.0: AI Safety & Human Oversight
# ──────────────────────────────────────────────────────────────────────────────

set -o pipefail

PASS=0; FAIL=0; ERRORS=""
pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }
check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.58.0 — AI Safety & Human Oversight"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. AI Safety Config Command"
check_file ".claude/commands/ai-safety-config.md" "ai-safety-config.md exists"
check_content ".claude/commands/ai-safety-config.md" "name: ai-safety-config" "Has correct name"
check_content ".claude/commands/ai-safety-config.md" "supervisión humana" "References human oversight"
check_content ".claude/commands/ai-safety-config.md" "agent: none" "Has agent: none"
echo ""

echo "📋 2. AI Confidence Command"
check_file ".claude/commands/ai-confidence.md" "ai-confidence.md exists"
check_content ".claude/commands/ai-confidence.md" "name: ai-confidence" "Has correct name"
check_content ".claude/commands/ai-confidence.md" "confianza" "References confidence"
check_content ".claude/commands/ai-confidence.md" "agent: task" "Has agent: task"
echo ""

echo "📋 3. AI Boundary Command"
check_file ".claude/commands/ai-boundary.md" "ai-boundary.md exists"
check_content ".claude/commands/ai-boundary.md" "name: ai-boundary" "Has correct name"
check_content ".claude/commands/ai-boundary.md" "límites" "References boundaries"
check_content ".claude/commands/ai-boundary.md" "agent: none" "Has agent: none"
echo ""

echo "📋 4. AI Incident Command"
check_file ".claude/commands/ai-incident.md" "ai-incident.md exists"
check_content ".claude/commands/ai-incident.md" "name: ai-incident" "Has correct name"
check_content ".claude/commands/ai-incident.md" "incidentes" "References incidents"
check_content ".claude/commands/ai-incident.md" "agent: task" "Has agent: task"
echo ""

echo "📋 5. Line Count Validation (≤150 lines each)"
CONFIG_LINES=$(wc -l < .claude/commands/ai-safety-config.md)
CONFIDENCE_LINES=$(wc -l < .claude/commands/ai-confidence.md)
BOUNDARY_LINES=$(wc -l < .claude/commands/ai-boundary.md)
INCIDENT_LINES=$(wc -l < .claude/commands/ai-incident.md)

[ "$CONFIG_LINES" -le 150 ] && pass "ai-safety-config.md: $CONFIG_LINES lines" || fail "ai-safety-config.md: $CONFIG_LINES lines (> 150)"
[ "$CONFIDENCE_LINES" -le 150 ] && pass "ai-confidence.md: $CONFIDENCE_LINES lines" || fail "ai-confidence.md: $CONFIDENCE_LINES lines (> 150)"
[ "$BOUNDARY_LINES" -le 150 ] && pass "ai-boundary.md: $BOUNDARY_LINES lines" || fail "ai-boundary.md: $BOUNDARY_LINES lines (> 150)"
[ "$INCIDENT_LINES" -le 150 ] && pass "ai-incident.md: $INCIDENT_LINES lines" || fail "ai-incident.md: $INCIDENT_LINES lines (> 150)"
echo ""

echo "📋 6. CLAUDE.md Updates"
# Dynamically check command count
EXPECTED_COUNT=$(ls -1 ".claude/commands"/*.md 2>/dev/null | wc -l)
if grep -q "commands/ ($EXPECTED_COUNT)" "CLAUDE.md" 2>/dev/null; then
  pass "CLAUDE.md has correct dynamic command count"
else
  fail "CLAUDE.md command count mismatch (expected: $EXPECTED_COUNT)"
fi
check_content "CLAUDE.md" "ai-safety-config" "CLAUDE.md references /ai-safety-config"
check_content "CLAUDE.md" "ai-confidence" "CLAUDE.md references /ai-confidence"
check_content "CLAUDE.md" "ai-boundary" "CLAUDE.md references /ai-boundary"
check_content "CLAUDE.md" "ai-incident" "CLAUDE.md references /ai-incident"
echo ""

echo "📋 7. README Updates"
check_content "README.md" "comando" "README.md references version"
check_content "README.md" "ai-safety-config" "README.md references /ai-safety-config"
check_content "README.md" "ai-confidence" "README.md references /ai-confidence"
check_content "README.md" "ai-boundary" "README.md references /ai-boundary"
check_content "README.md" "ai-incident" "README.md references /ai-incident"
check_content "README.en.md" "command"
echo ""

echo "📋 8. CHANGELOG"
check_content "CHANGELOG.md" "0.58.0" "CHANGELOG has v0.58.0 entry"
check_content "CHANGELOG.md" "AI Safety & Human Oversight" "CHANGELOG describes AI Safety feature"
check_content "CHANGELOG.md" "ai-safety-config" "CHANGELOG mentions /ai-safety-config"
check_content "CHANGELOG.md" "ai-confidence" "CHANGELOG mentions /ai-confidence"
check_content "CHANGELOG.md" "ai-boundary" "CHANGELOG mentions /ai-boundary"
check_content "CHANGELOG.md" "ai-incident" "CHANGELOG mentions /ai-incident"
check_content "CHANGELOG.md" "0.58.0" "CHANGELOG mentions v0.58.0 version"
echo ""

echo "📋 9. Command Structure Validation"
# Check frontmatter
for cmd in ai-safety-config ai-confidence ai-boundary ai-incident; do
  check_content ".claude/commands/$cmd.md" "^---$" "$cmd.md has frontmatter start"
  check_content ".claude/commands/$cmd.md" "^name:" "$cmd.md has name field"
  check_content ".claude/commands/$cmd.md" "^description:" "$cmd.md has description field"
  check_content ".claude/commands/$cmd.md" "^agent:" "$cmd.md has agent field"
done
echo ""

echo "📋 10. Command Metadata Validation"
check_content ".claude/commands/ai-safety-config.md" "context_cost: low" "ai-safety-config has context_cost"
check_content ".claude/commands/ai-confidence.md" "context_cost: low" "ai-confidence has context_cost"
check_content ".claude/commands/ai-boundary.md" "context_cost: low" "ai-boundary has context_cost"
check_content ".claude/commands/ai-incident.md" "context_cost: medium" "ai-incident has context_cost"
echo ""

echo "📋 11. Content Validation"
check_content ".claude/commands/ai-safety-config.md" "inform\|recommend\|decide\|execute" "ai-safety-config defines 4 levels"
check_content ".claude/commands/ai-confidence.md" "ALTA\|MEDIA\|BAJA" "ai-confidence defines confidence levels"
check_content ".claude/commands/ai-boundary.md" "Matriz de Límites" "ai-boundary has boundary matrix"
check_content ".claude/commands/ai-incident.md" "BIAS\|HALLUCINATION\|CONTEXT-LOSS\|OUTDATED" "ai-incident defines incident types"
echo ""

echo "📋 12. Regression (existing commands)"
check_file ".claude/commands/ai-model-card.md" "ai-model-card still exists"
check_file ".claude/commands/ai-risk-assessment.md" "ai-risk-assessment still exists"
check_file ".claude/commands/async-standup.md" "async-standup still exists"
check_file ".claude/commands/backlog-groom.md" "backlog-groom still exists (v0.56.0)"
check_file ".claude/commands/okr-define.md" "okr-define still exists (v0.55.0)"
echo ""

echo "📋 13. Test Suite Exists"
check_file "scripts/test-ai-safety.sh" "test-ai-safety.sh exists"
echo ""

TOTAL=$((PASS + FAIL))
echo "═══════════════════════════════════════════════════════════════"
echo "  📊 Results: $PASS/$TOTAL passed"
echo "═══════════════════════════════════════════════════════════════"
if [ "$FAIL" -gt 0 ]; then
  echo ""; echo "  Failures:"; echo -e "$ERRORS"; exit 1
fi
echo ""; echo "  ✅ All tests passed!"; exit 0
