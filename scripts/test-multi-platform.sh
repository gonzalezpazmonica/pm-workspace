#!/usr/bin/env bash
# ── test-multi-platform.sh ──────────────────────────────────────────────────
# Tests for v0.53.0: Multi-Platform Support
# ──────────────────────────────────────────────────────────────────────────────

set -uo pipefail

PASS=0; FAIL=0; ERRORS=""
pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }
check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.53.0 — Multi-Platform Support"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. Jira Connect Command"
check_file ".claude/commands/jira-connect.md" "jira-connect.md exists"
check_content ".claude/commands/jira-connect.md" "name: jira-connect" "Has correct name"
check_content ".claude/commands/jira-connect.md" "Jira" "References Jira"
check_content ".claude/commands/jira-connect.md" "sync\|Sync" "Includes sync/Sync"
check_content ".claude/commands/jira-connect.md" "mapeo\|Mapping" "Includes mapeo/Mapping"
check_content ".claude/commands/jira-connect.md" "bidireccional" "Has bidireccional"
check_content ".claude/commands/jira-connect.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 2. GitHub Projects Command"
check_file ".claude/commands/github-projects.md" "github-projects.md exists"
check_content ".claude/commands/github-projects.md" "name: github-projects" "Has correct name"
check_content ".claude/commands/github-projects.md" "GitHub Projects" "References GitHub Projects"
check_content ".claude/commands/github-projects.md" "GraphQL" "Includes GraphQL"
check_content ".claude/commands/github-projects.md" "Kanban\|board" "Includes Kanban/board"
check_content ".claude/commands/github-projects.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 3. Linear Sync Command (updated)"
check_file ".claude/commands/linear-sync.md" "linear-sync.md exists"
check_content ".claude/commands/linear-sync.md" "name: linear-sync" "Has correct name"
check_content ".claude/commands/linear-sync.md" "Linear" "References Linear"
check_content ".claude/commands/linear-sync.md" "bidireccional" "Has bidireccional"
check_content ".claude/commands/linear-sync.md" "webhook" "Mentions webhook"
check_content ".claude/commands/linear-sync.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 4. Platform Migrate Command"
check_file ".claude/commands/platform-migrate.md" "platform-migrate.md exists"
check_content ".claude/commands/platform-migrate.md" "name: platform-migrate" "Has correct name"
check_content ".claude/commands/platform-migrate.md" "migra" "Includes migra"
check_content ".claude/commands/platform-migrate.md" "dry-run\|dry.run" "Includes dry-run/dry.run"
check_content ".claude/commands/platform-migrate.md" "rollback" "Mentions rollback"
check_content ".claude/commands/platform-migrate.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 5. CLAUDE.md Updates"
check_content "CLAUDE.md" "commands/ (181)" "CLAUDE.md shows 181 commands"
check_content "CLAUDE.md" "jira-connect" "CLAUDE.md references /jira-connect"
check_content "CLAUDE.md" "github-projects" "CLAUDE.md references /github-projects"
check_content "CLAUDE.md" "platform-migrate" "CLAUDE.md references /platform-migrate"
echo ""

echo "📋 6. README Updates"
check_content "README.md" "181 comandos" "README.md shows 181 commands"
check_content "README.md" "jira-connect" "README.md references /jira-connect"
check_content "README.en.md" "181 commands" "README.en.md shows 181 commands"
check_content "README.en.md" "jira-connect" "README.en.md references /jira-connect"
echo ""

echo "📋 7. Context Map & Workflows"
check_content ".claude/profiles/context-map.md" "jira-connect" "Context-map includes /jira-connect"
check_content ".claude/profiles/context-map.md" "platform-migrate" "Context-map includes /platform-migrate"
check_content ".claude/rules/domain/role-workflows.md" "platform-migrate" "Role-workflows includes /platform-migrate"
echo ""

echo "📋 8. CHANGELOG"
check_content "CHANGELOG.md" "0.53.0" "CHANGELOG has v0.53.0 entry"
check_content "CHANGELOG.md" "Multi-Platform" "CHANGELOG describes Multi-Platform"
check_content "CHANGELOG.md" "compare/v0.52.0...v0.53.0" "CHANGELOG has v0.53.0 link"
echo ""

echo "📋 9. Regression"
check_file ".claude/commands/mcp-server.md" "mcp-server still exists (v0.52.0)"
check_file ".claude/commands/sprint-autoplan.md" "sprint-autoplan still exists (v0.51.0)"
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
