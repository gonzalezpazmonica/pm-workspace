#!/usr/bin/env bash
# ── test-tech-lead.sh ─────────────────────────────────────────────────────
# Tests for v0.48.0: Tech Lead Intelligence
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
echo "  🧪 Test Suite: v0.48.0 — Tech Lead Intelligence"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. Tech Radar Command"
check_file ".claude/commands/tech-radar.md" "tech-radar.md exists"
check_content ".claude/commands/tech-radar.md" "name: tech-radar" "Has correct name"
check_content ".claude/commands/tech-radar.md" "Adopt" "Has adopt category"
check_content ".claude/commands/tech-radar.md" "Retire" "Has retire category"
check_content ".claude/commands/tech-radar.md" "CVE" "Checks for CVEs"
check_content ".claude/commands/tech-radar.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 2. Team Skills Matrix Command"
check_file ".claude/commands/team-skills-matrix.md" "team-skills-matrix.md exists"
check_content ".claude/commands/team-skills-matrix.md" "name: team-skills-matrix" "Has correct name"
check_content ".claude/commands/team-skills-matrix.md" "Bus Factor" "Calculates bus factor"
check_content ".claude/commands/team-skills-matrix.md" "pair programming" "Suggests pair programming"
check_content ".claude/commands/team-skills-matrix.md" "evaluación de rendimiento" "Not for performance evaluation"
check_content ".claude/commands/team-skills-matrix.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 3. Arch Health Command"
check_file ".claude/commands/arch-health.md" "arch-health.md exists"
check_content ".claude/commands/arch-health.md" "name: arch-health" "Has correct name"
check_content ".claude/commands/arch-health.md" "fitness" "Uses fitness functions"
check_content ".claude/commands/arch-health.md" "drift" "Detects drift"
check_content ".claude/commands/arch-health.md" "Coupling" "Calculates coupling"
check_content ".claude/commands/arch-health.md" "Instability" "Calculates instability"
check_content ".claude/commands/arch-health.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 4. Incident Postmortem Command"
check_file ".claude/commands/incident-postmortem.md" "incident-postmortem.md exists"
check_content ".claude/commands/incident-postmortem.md" "name: incident-postmortem" "Has correct name"
check_content ".claude/commands/incident-postmortem.md" "Timeline" "Builds timeline"
check_content ".claude/commands/incident-postmortem.md" "Root Cause" "Does root cause analysis"
check_content ".claude/commands/incident-postmortem.md" "5 Whys" "Uses 5 Whys method"
check_content ".claude/commands/incident-postmortem.md" "blameless" "Blameless approach"
check_content ".claude/commands/incident-postmortem.md" "Action Items" "Has action items"
check_content ".claude/commands/incident-postmortem.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 5. CLAUDE.md Updates"
check_content "CLAUDE.md" "commands/ (166)" "CLAUDE.md shows 166 commands"
check_content "CLAUDE.md" "tech-radar" "CLAUDE.md references /tech-radar"
check_content "CLAUDE.md" "team-skills-matrix" "CLAUDE.md references /team-skills-matrix"
check_content "CLAUDE.md" "arch-health" "CLAUDE.md references /arch-health"
check_content "CLAUDE.md" "incident-postmortem" "CLAUDE.md references /incident-postmortem"
echo ""

echo "📋 6. README Updates"
check_content "README.md" "166 comandos" "README.md shows 166 commands"
check_content "README.md" "tech-radar" "README.md references /tech-radar"
check_content "README.md" "team-skills-matrix" "README.md references /team-skills-matrix"
check_content "README.en.md" "166 commands" "README.en.md shows 166 commands"
check_content "README.en.md" "tech-radar" "README.en.md references /tech-radar"
echo ""

echo "📋 7. Context Map & Workflows"
check_content ".claude/profiles/context-map.md" "tech-radar" "Context-map includes /tech-radar"
check_content ".claude/profiles/context-map.md" "team-skills-matrix" "Context-map includes /team-skills-matrix"
check_content ".claude/rules/domain/role-workflows.md" "arch-health" "TL routine uses /arch-health"
check_content ".claude/rules/domain/role-workflows.md" "team-skills-matrix" "TL routine uses /team-skills-matrix"
echo ""

echo "📋 8. CHANGELOG"
check_content "CHANGELOG.md" "0.48.0" "CHANGELOG has v0.48.0 entry"
check_content "CHANGELOG.md" "Tech Lead Intelligence" "CHANGELOG describes tech lead"
check_content "CHANGELOG.md" "compare/v0.47.0...v0.48.0" "CHANGELOG has v0.48.0 link"
echo ""

echo "📋 9. Regression"
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
