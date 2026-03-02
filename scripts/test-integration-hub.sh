#!/usr/bin/env bash
# ── test-integration-hub.sh ─────────────────────────────────────────────────
# Tests for v0.52.0: Integration Hub
# ──────────────────────────────────────────────────────────────────────────────

set -o pipefail

PASS=0; FAIL=0; ERRORS=""
pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }
check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.52.0 — Integration Hub"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. MCP Server Command"
check_file ".claude/commands/mcp-server.md" "mcp-server.md exists"
check_content ".claude/commands/mcp-server.md" "name: mcp-server" "Has correct name"
check_content ".claude/commands/mcp-server.md" "MCP" "References MCP"
check_content ".claude/commands/mcp-server.md" "herramienta\|tools" "Includes tools/herramienta"
check_content ".claude/commands/mcp-server.md" "stdio" "Mentions stdio"
check_content ".claude/commands/mcp-server.md" "permis" "Includes permissions"
check_content ".claude/commands/mcp-server.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 2. NL Query Command"
check_file ".claude/commands/nl-query.md" "nl-query.md exists"
check_content ".claude/commands/nl-query.md" "name: nl-query" "Has correct name"
check_content ".claude/commands/nl-query.md" "lenguaje natural\|natural" "Mentions natural language"
check_content ".claude/commands/nl-query.md" "Interpretar\|intención" "Includes interpretation"
check_content ".claude/commands/nl-query.md" "confianza\|Confianza" "Addresses confidence"
check_content ".claude/commands/nl-query.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 3. Webhook Config Command"
check_file ".claude/commands/webhook-config.md" "webhook-config.md exists"
check_content ".claude/commands/webhook-config.md" "name: webhook-config" "Has correct name"
check_content ".claude/commands/webhook-config.md" "webhook" "Mentions webhook"
check_content ".claude/commands/webhook-config.md" "azure-devops\|Azure" "References Azure/azure-devops"
check_content ".claude/commands/webhook-config.md" "HMAC" "Includes HMAC"
check_content ".claude/commands/webhook-config.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 4. Integration Status Command"
check_file ".claude/commands/integration-status.md" "integration-status.md exists"
check_content ".claude/commands/integration-status.md" "name: integration-status" "Has correct name"
check_content ".claude/commands/integration-status.md" "dashboard\|Dashboard" "References dashboard"
check_content ".claude/commands/integration-status.md" "health\|Estado" "Addresses health/status"
check_content ".claude/commands/integration-status.md" "repair\|Reparación" "Includes repair capability"
check_content ".claude/commands/integration-status.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 5. CLAUDE.md Updates"
# Dynamically check command count
EXPECTED_COUNT=$(ls -1 ".claude/commands"/*.md 2>/dev/null | wc -l)
if grep -q "commands/ ($EXPECTED_COUNT)" "CLAUDE.md" 2>/dev/null; then
  pass "CLAUDE.md has correct dynamic command count"
else
  fail "CLAUDE.md command count mismatch (expected: $EXPECTED_COUNT)"
fi
check_content "CLAUDE.md" "mcp-server" "CLAUDE.md references /mcp-server"
check_content "CLAUDE.md" "nl-query" "CLAUDE.md references /nl-query"
check_content "CLAUDE.md" "webhook-config" "CLAUDE.md references /webhook-config"
check_content "CLAUDE.md" "integration-status" "CLAUDE.md references /integration-status"
echo ""

echo "📋 6. README Updates"
check_content "README.md" "comando" "README.md references version"
check_content "README.md" "mcp-server" "README.md references /mcp-server"
check_content "README.en.md" "command"
check_content "README.en.md" "mcp-server" "README.en.md references /mcp-server"
echo ""

echo "📋 7. Context Map & Workflows"
check_content ".claude/profiles/context-map.md" "mcp-server" "Context-map includes /mcp-server"
check_content ".claude/profiles/context-map.md" "integration-status" "Context-map includes /integration-status"
check_content ".claude/rules/domain/role-workflows.md" "integration-status" "Role-workflows includes /integration-status"
echo ""

echo "📋 8. CHANGELOG"
check_content "CHANGELOG.md" "0.52.0" "CHANGELOG has v0.52.0 entry"
check_content "CHANGELOG.md" "Integration Hub" "CHANGELOG describes Integration Hub"
check_content "CHANGELOG.md" "compare/v0.51.0...v0.52.0" "CHANGELOG has v0.52.0 link"
echo ""

echo "📋 9. Regression"
check_file ".claude/commands/sprint-autoplan.md" "sprint-autoplan still exists"
check_file ".claude/commands/portfolio-deps.md" "portfolio-deps still exists"
check_file ".claude/commands/ceo-report.md" "ceo-report still exists"
echo ""

TOTAL=$((PASS + FAIL))
echo "═══════════════════════════════════════════════════════════════"
echo "  📊 Results: $PASS/$TOTAL passed"
echo "═══════════════════════════════════════════════════════════════"
if [ "$FAIL" -gt 0 ]; then
  echo ""; echo "  Failures:"; echo -e "$ERRORS"; exit 1
fi
echo ""; echo "  ✅ All tests passed!"; exit 0
