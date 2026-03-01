#!/bin/bash
# test-contribute.sh — Tests del sistema de comunidad y contribución
set -euo pipefail

PASS=0
FAIL=0
WORKSPACE_DIR="${PM_WORKSPACE_ROOT:-$HOME/claude}"

pass() { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

check_file() {
  local file="$WORKSPACE_DIR/$1"
  local label="$2"
  [ -f "$file" ] && pass "Existe: $label" || fail "No existe: $label"
}

check_contains() {
  local file="$WORKSPACE_DIR/$1"
  local pattern="$2"
  local label="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    pass "Contiene '$pattern' en $label"
  else
    fail "No contiene '$pattern' en $label"
  fi
}

check_executable() {
  local file="$WORKSPACE_DIR/$1"
  local label="$2"
  [ -x "$file" ] && pass "Ejecutable: $label" || fail "No ejecutable: $label"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Test Suite: Community & Contribution System"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "📄 Ficheros del sistema de comunidad"
check_file "scripts/contribute.sh" "scripts/contribute.sh"
check_executable "scripts/contribute.sh" "scripts/contribute.sh"
check_file ".claude/commands/contribute.md" ".claude/commands/contribute.md"
check_file ".claude/commands/feedback.md" ".claude/commands/feedback.md"
check_file ".claude/rules/domain/community-protocol.md" "community-protocol.md"

echo ""
echo "🔧 Contenido de scripts/contribute.sh"
check_contains "scripts/contribute.sh" "validate_privacy" "contribute.sh"
check_contains "scripts/contribute.sh" "do_pr" "contribute.sh"
check_contains "scripts/contribute.sh" "do_issue" "contribute.sh"
check_contains "scripts/contribute.sh" "do_list" "contribute.sh"
check_contains "scripts/contribute.sh" "do_search" "contribute.sh"
check_contains "scripts/contribute.sh" "AKIA" "contribute.sh (AWS key pattern)"
check_contains "scripts/contribute.sh" "ghp_" "contribute.sh (GitHub PAT pattern)"
check_contains "scripts/contribute.sh" "sk-" "contribute.sh (OpenAI key pattern)"
check_contains "scripts/contribute.sh" "eyJ" "contribute.sh (JWT pattern)"
check_contains "scripts/contribute.sh" "CLAUDE.local.md" "contribute.sh (project names)"
check_contains "scripts/contribute.sh" "pm-workspace" "contribute.sh (repo name)"
check_contains "scripts/contribute.sh" "community" "contribute.sh (label)"
check_contains "scripts/contribute.sh" "from-savia" "contribute.sh (label)"
check_contains "scripts/contribute.sh" "gh issue create" "contribute.sh (gh issue)"
check_contains "scripts/contribute.sh" "gh pr list" "contribute.sh (gh pr list)"
check_contains "scripts/contribute.sh" "gh issue list" "contribute.sh (gh issue list)"

echo ""
echo "📋 Contenido de contribute.md (comando)"
check_contains ".claude/commands/contribute.md" "name: contribute" "contribute.md"
check_contains ".claude/commands/contribute.md" "pr" "contribute.md"
check_contains ".claude/commands/contribute.md" "idea" "contribute.md"
check_contains ".claude/commands/contribute.md" "bug" "contribute.md"
check_contains ".claude/commands/contribute.md" "status" "contribute.md"
check_contains ".claude/commands/contribute.md" "validate_privacy" "contribute.md"
check_contains ".claude/commands/contribute.md" "community-protocol" "contribute.md"
check_contains ".claude/commands/contribute.md" "Savia" "contribute.md"
check_contains ".claude/commands/contribute.md" "NUNCA" "contribute.md"

echo ""
echo "📋 Contenido de feedback.md (comando)"
check_contains ".claude/commands/feedback.md" "name: feedback" "feedback.md"
check_contains ".claude/commands/feedback.md" "bug" "feedback.md"
check_contains ".claude/commands/feedback.md" "idea" "feedback.md"
check_contains ".claude/commands/feedback.md" "improve" "feedback.md"
check_contains ".claude/commands/feedback.md" "list" "feedback.md"
check_contains ".claude/commands/feedback.md" "search" "feedback.md"
check_contains ".claude/commands/feedback.md" "contribute.sh" "feedback.md"
check_contains ".claude/commands/feedback.md" "Savia" "feedback.md"
check_contains ".claude/commands/feedback.md" "NUNCA" "feedback.md"

echo ""
echo "🔒 Contenido de community-protocol.md"
check_contains ".claude/rules/domain/community-protocol.md" "Privacy-first" "community-protocol.md"
check_contains ".claude/rules/domain/community-protocol.md" "PATs" "community-protocol.md"
check_contains ".claude/rules/domain/community-protocol.md" "Emails corporativos" "community-protocol.md"
check_contains ".claude/rules/domain/community-protocol.md" "CLAUDE.local.md" "community-protocol.md"
check_contains ".claude/rules/domain/community-protocol.md" "validate_privacy" "community-protocol.md"
check_contains ".claude/rules/domain/community-protocol.md" "from-savia" "community-protocol.md"
check_contains ".claude/rules/domain/community-protocol.md" "Plantilla de PR" "community-protocol.md"
check_contains ".claude/rules/domain/community-protocol.md" "Plantilla de Issue" "community-protocol.md"

echo ""
echo "🪝 Integración con session-init.sh"
check_contains ".claude/hooks/session-init.sh" "contribute" "session-init.sh"
check_contains ".claude/hooks/session-init.sh" "RANDOM" "session-init.sh"
check_contains ".claude/hooks/session-init.sh" "/contribute" "session-init.sh"
check_contains ".claude/hooks/session-init.sh" "/feedback" "session-init.sh"

echo ""
echo "📖 Integración con CLAUDE.md"
check_contains "CLAUDE.md" "/contribute" "CLAUDE.md"
check_contains "CLAUDE.md" "/feedback" "CLAUDE.md"
check_contains "CLAUDE.md" "commands/ (147)" "CLAUDE.md"

echo ""
echo "📖 Integración con README.md"
check_contains "README.md" "/contribute" "README.md"
check_contains "README.md" "/feedback" "README.md"
check_contains "README.md" "147 comandos" "README.md"
check_contains "README.md" "Comunidad" "README.md"

echo ""
echo "📖 Integración con README.en.md"
check_contains "README.en.md" "/contribute" "README.en.md"
check_contains "README.en.md" "/feedback" "README.en.md"
check_contains "README.en.md" "147 commands" "README.en.md"
check_contains "README.en.md" "Community" "README.en.md"

echo ""
echo "🔐 Privacy validation funciona"
VALIDATE_OUTPUT=$(cd "$WORKSPACE_DIR" && bash scripts/contribute.sh validate "texto limpio sin datos privados" 2>&1)
if echo "$VALIDATE_OUTPUT" | grep -q "limpio"; then
  pass "validate_privacy acepta texto limpio"
else
  fail "validate_privacy NO acepta texto limpio"
fi

VALIDATE_DIRTY=$(cd "$WORKSPACE_DIR" && bash scripts/contribute.sh validate "mi token es ghp_abcdefghijklmnopqrstuvwxyz1234567890" 2>&1 || true)
if echo "$VALIDATE_DIRTY" | grep -q "GitHub PAT"; then
  pass "validate_privacy detecta GitHub PAT"
else
  fail "validate_privacy NO detecta GitHub PAT"
fi

VALIDATE_AWS=$(cd "$WORKSPACE_DIR" && bash scripts/contribute.sh validate "clave AKIAIOSFODNN7EXAMPLE" 2>&1 || true)
if echo "$VALIDATE_AWS" | grep -q "AWS"; then
  pass "validate_privacy detecta AWS key"
else
  fail "validate_privacy NO detecta AWS key"
fi

echo ""
echo "⚙️  Hook produce JSON válido"
HOOK_OUTPUT=$(cd "$WORKSPACE_DIR" && bash .claude/hooks/session-init.sh 2>/dev/null)
if echo "$HOOK_OUTPUT" | jq . >/dev/null 2>&1; then
  pass "session-init.sh produce JSON válido"
else
  fail "session-init.sh NO produce JSON válido"
fi

echo ""
echo "📋 contribute.sh help funciona"
HELP_OUTPUT=$(cd "$WORKSPACE_DIR" && bash scripts/contribute.sh help 2>&1)
if echo "$HELP_OUTPUT" | grep -q "Comandos"; then
  pass "contribute.sh help muestra ayuda"
else
  fail "contribute.sh help NO muestra ayuda"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASS + FAIL))
echo "📊 Resultado: $PASS/$TOTAL tests passed ($FAIL failed)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$FAIL" -eq 0 ]; then
  echo "✅ Todos los tests pasaron"
else
  echo "❌ Hay tests fallidos"
  exit 1
fi
