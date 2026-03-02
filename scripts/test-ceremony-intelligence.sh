#!/usr/bin/env bash
# ── test-ceremony-intelligence.sh ────────────────────────────────────────────
# Tests for v0.57.0: Ceremony Intelligence
# ──────────────────────────────────────────────────────────────────────────────

set -o pipefail

PASS=0; FAIL=0; ERRORS=""
pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }
check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.57.0 — Ceremony Intelligence"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. Async Standup Command"
check_file ".claude/commands/async-standup.md" "async-standup.md exists"
check_content ".claude/commands/async-standup.md" "name: async-standup" "Has correct name"
check_content ".claude/commands/async-standup.md" "asíncrono" "References async"
check_content ".claude/commands/async-standup.md" "agent: task" "Has agent: task"
echo ""

echo "📋 2. Retro Patterns Command"
check_file ".claude/commands/retro-patterns.md" "retro-patterns.md exists"
check_content ".claude/commands/retro-patterns.md" "name: retro-patterns" "Has correct name"
check_content ".claude/commands/retro-patterns.md" "patrones" "References patterns"
check_content ".claude/commands/retro-patterns.md" "agent: task" "Has agent: task"
echo ""

echo "📋 3. Ceremony Health Command"
check_file ".claude/commands/ceremony-health.md" "ceremony-health.md exists"
check_content ".claude/commands/ceremony-health.md" "name: ceremony-health" "Has correct name"
check_content ".claude/commands/ceremony-health.md" "salud de ceremonias" "References ceremony health"
check_content ".claude/commands/ceremony-health.md" "agent: task" "Has agent: task"
echo ""

echo "📋 4. Meeting Agenda Command"
check_file ".claude/commands/meeting-agenda.md" "meeting-agenda.md exists"
check_content ".claude/commands/meeting-agenda.md" "name: meeting-agenda" "Has correct name"
check_content ".claude/commands/meeting-agenda.md" "Agenda inteligente" "References intelligent agenda"
check_content ".claude/commands/meeting-agenda.md" "agent: none" "Has agent: none"
echo ""

echo "📋 5. Line Count Validation (≤150 lines each)"
ASYNC_LINES=$(wc -l < .claude/commands/async-standup.md)
RETRO_LINES=$(wc -l < .claude/commands/retro-patterns.md)
CEREMONY_LINES=$(wc -l < .claude/commands/ceremony-health.md)
AGENDA_LINES=$(wc -l < .claude/commands/meeting-agenda.md)

[ "$ASYNC_LINES" -le 150 ] && pass "async-standup.md: $ASYNC_LINES lines" || fail "async-standup.md: $ASYNC_LINES lines (> 150)"
[ "$RETRO_LINES" -le 150 ] && pass "retro-patterns.md: $RETRO_LINES lines" || fail "retro-patterns.md: $RETRO_LINES lines (> 150)"
[ "$CEREMONY_LINES" -le 150 ] && pass "ceremony-health.md: $CEREMONY_LINES lines" || fail "ceremony-health.md: $CEREMONY_LINES lines (> 150)"
[ "$AGENDA_LINES" -le 150 ] && pass "meeting-agenda.md: $AGENDA_LINES lines" || fail "meeting-agenda.md: $AGENDA_LINES lines (> 150)"
echo ""

echo "📋 6. CLAUDE.md Updates"
# Dynamically check command count
EXPECTED_COUNT=$(ls -1 ".claude/commands"/*.md 2>/dev/null | wc -l)
if grep -q "commands/ ($EXPECTED_COUNT)" "CLAUDE.md" 2>/dev/null; then
  pass "CLAUDE.md has correct dynamic command count"
else
  fail "CLAUDE.md command count mismatch (expected: $EXPECTED_COUNT)"
fi
check_content "CLAUDE.md" "async-standup" "CLAUDE.md references /async-standup"
check_content "CLAUDE.md" "retro-patterns" "CLAUDE.md references /retro-patterns"
check_content "CLAUDE.md" "ceremony-health" "CLAUDE.md references /ceremony-health"
check_content "CLAUDE.md" "meeting-agenda" "CLAUDE.md references /meeting-agenda"
check_content "CLAUDE.md" "Ceremony Intelligence" "CLAUDE.md has Ceremony Intelligence section"
echo ""

echo "📋 7. README Updates"
check_content "README.md" "comando" "README.md references version"
check_content "README.md" "Ceremony Intelligence" "README.md has Ceremony Intelligence section"
check_content "README.md" "async-standup" "README.md references /async-standup"
check_content "README.md" "retro-patterns" "README.md references /retro-patterns"
check_content "README.en.md" "command"
check_content "README.en.md" "Ceremony Intelligence" "README.en.md has Ceremony Intelligence section"
echo ""

echo "📋 8. CHANGELOG"
check_content "CHANGELOG.md" "0.57.0" "CHANGELOG has v0.57.0 entry"
check_content "CHANGELOG.md" "Ceremony Intelligence" "CHANGELOG describes Ceremony Intelligence"
check_content "CHANGELOG.md" "async-standup" "CHANGELOG mentions /async-standup"
check_content "CHANGELOG.md" "retro-patterns" "CHANGELOG mentions /retro-patterns"
check_content "CHANGELOG.md" "ceremony-health" "CHANGELOG mentions /ceremony-health"
check_content "CHANGELOG.md" "meeting-agenda" "CHANGELOG mentions /meeting-agenda"
check_content "CHANGELOG.md" "0.57.0" "CHANGELOG mentions v0.57.0 version"
echo ""

echo "📋 9. Context Map & Workflows"
check_content ".claude/profiles/context-map.md" "async-standup" "Context-map includes async-standup command"
check_content ".claude/rules/domain/role-workflows.md" "PM\|Scrum Master" "Role-workflows covers PM/Scrum Master"
echo ""

echo "📋 10. Command Structure Validation"
# Check frontmatter
for cmd in async-standup retro-patterns ceremony-health meeting-agenda; do
  check_content ".claude/commands/$cmd.md" "^---$" "$cmd.md has frontmatter start"
done
echo ""

echo "📋 11. Regression (existing commands)"
check_file ".claude/commands/backlog-groom.md" "backlog-groom still exists"
check_file ".claude/commands/okr-define.md" "okr-define still exists"
check_file ".claude/commands/company-setup.md" "company-setup still exists"
echo ""

TOTAL=$((PASS + FAIL))
echo "═══════════════════════════════════════════════════════════════"
echo "  📊 Results: $PASS/$TOTAL passed"
echo "═══════════════════════════════════════════════════════════════"
if [ "$FAIL" -gt 0 ]; then
  echo ""; echo "  Failures:"; echo -e "$ERRORS"; exit 1
fi
echo ""; echo "  ✅ All tests passed!"; exit 0
