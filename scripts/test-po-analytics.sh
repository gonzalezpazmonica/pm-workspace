#!/usr/bin/env bash
# ── test-po-analytics.sh ─────────────────────────────────────────────────
# Tests for v0.49.0: Product Owner Analytics
# ──────────────────────────────────────────────────────────────────────────

set -uo pipefail

PASS=0
FAIL=0
ERRORS=""

pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }

check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.49.0 — Product Owner Analytics"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. Value Stream Map Command"
check_file ".claude/commands/value-stream-map.md" "value-stream-map.md exists"
check_content ".claude/commands/value-stream-map.md" "name: value-stream-map" "Has correct name"
check_content ".claude/commands/value-stream-map.md" "Lead Time" "Calculates lead time"
check_content ".claude/commands/value-stream-map.md" "Flow Efficiency" "Calculates flow efficiency"
check_content ".claude/commands/value-stream-map.md" "waste" "Identifies waste"
check_content ".claude/commands/value-stream-map.md" "bottleneck" "Detects bottlenecks"
check_content ".claude/commands/value-stream-map.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 2. Feature Impact Command"
check_file ".claude/commands/feature-impact.md" "feature-impact.md exists"
check_content ".claude/commands/feature-impact.md" "name: feature-impact" "Has correct name"
check_content ".claude/commands/feature-impact.md" "ROI" "Calculates ROI"
check_content ".claude/commands/feature-impact.md" "Business Value" "Uses business value"
check_content ".claude/commands/feature-impact.md" "Priorizar" "Gives prioritization recommendations"
check_content ".claude/commands/feature-impact.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 3. Stakeholder Report Command"
check_file ".claude/commands/stakeholder-report.md" "stakeholder-report.md exists"
check_content ".claude/commands/stakeholder-report.md" "name: stakeholder-report" "Has correct name"
check_content ".claude/commands/stakeholder-report.md" "roadmap" "Includes roadmap view"
check_content ".claude/commands/stakeholder-report.md" "Riesgos" "Reports risks"
check_content ".claude/commands/stakeholder-report.md" "jerga técnica" "Avoids technical jargon"
check_content ".claude/commands/stakeholder-report.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 4. Release Readiness Command"
check_file ".claude/commands/release-readiness.md" "release-readiness.md exists"
check_content ".claude/commands/release-readiness.md" "name: release-readiness" "Has correct name"
check_content ".claude/commands/release-readiness.md" "Quality Gate" "Has quality gate"
check_content ".claude/commands/release-readiness.md" "Deployment" "Checks deployment readiness"
check_content ".claude/commands/release-readiness.md" "Go / No-Go" "Has go/no-go decision"
check_content ".claude/commands/release-readiness.md" "Rollback" "Checks rollback plan"
check_content ".claude/commands/release-readiness.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 5. CLAUDE.md Updates"
check_content "CLAUDE.md" "commands/ (166)" "CLAUDE.md shows 166 commands"
check_content "CLAUDE.md" "value-stream-map" "CLAUDE.md references /value-stream-map"
check_content "CLAUDE.md" "feature-impact" "CLAUDE.md references /feature-impact"
check_content "CLAUDE.md" "stakeholder-report" "CLAUDE.md references /stakeholder-report"
check_content "CLAUDE.md" "release-readiness" "CLAUDE.md references /release-readiness"
echo ""

echo "📋 6. README Updates"
check_content "README.md" "166 comandos" "README.md shows 166 commands"
check_content "README.md" "value-stream-map" "README.md references /value-stream-map"
check_content "README.md" "stakeholder-report" "README.md references /stakeholder-report"
check_content "README.en.md" "166 commands" "README.en.md shows 166 commands"
check_content "README.en.md" "value-stream-map" "README.en.md references /value-stream-map"
echo ""

echo "📋 7. Context Map & Workflows"
check_content ".claude/profiles/context-map.md" "value-stream-map" "Context-map includes /value-stream-map"
check_content ".claude/profiles/context-map.md" "stakeholder-report" "Context-map includes /stakeholder-report"
check_content ".claude/rules/domain/role-workflows.md" "value-stream-map" "PO routine uses /value-stream-map"
check_content ".claude/rules/domain/role-workflows.md" "stakeholder-report" "PO routine uses /stakeholder-report"
check_content ".claude/rules/domain/role-workflows.md" "feature-impact" "PO routine uses /feature-impact"
echo ""

echo "📋 8. CHANGELOG"
check_content "CHANGELOG.md" "0.49.0" "CHANGELOG has v0.49.0 entry"
check_content "CHANGELOG.md" "Product Owner" "CHANGELOG describes product owner"
check_content "CHANGELOG.md" "compare/v0.48.0...v0.49.0" "CHANGELOG has v0.49.0 link"
echo ""

echo "📋 9. Regression"
check_file ".claude/commands/tech-radar.md" "tech-radar still exists (v0.48.0)"
check_file ".claude/commands/my-sprint.md" "my-sprint still exists (v0.47.0)"
check_file ".claude/commands/qa-dashboard.md" "qa-dashboard still exists (v0.46.0)"
check_file ".claude/commands/ceo-report.md" "ceo-report still exists (v0.45.0)"
echo ""

TOTAL=$((PASS + FAIL))
echo "═══════════════════════════════════════════════════════════════"
echo "  📊 Results: $PASS/$TOTAL passed"
echo "═══════════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo ""; echo "  Failures:"; echo -e "$ERRORS"; exit 1
fi
echo ""; echo "  ✅ All tests passed!"; exit 0
