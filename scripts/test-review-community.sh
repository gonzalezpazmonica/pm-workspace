#!/bin/bash
# test-review-community.sh — Tests del protocolo de revisión comunitaria
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
echo "🧪 Test Suite: Review Community Protocol"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "📄 Ficheros del protocolo de revisión"
check_file "scripts/review-community.sh" "scripts/review-community.sh"
check_executable "scripts/review-community.sh" "scripts/review-community.sh"
check_file ".claude/commands/review-community.md" "review-community.md"

echo ""
echo "🔧 Contenido de scripts/review-community.sh"
check_contains "scripts/review-community.sh" "do_pending" "review-community.sh"
check_contains "scripts/review-community.sh" "do_review" "review-community.sh"
check_contains "scripts/review-community.sh" "do_merge" "review-community.sh"
check_contains "scripts/review-community.sh" "do_release" "review-community.sh"
check_contains "scripts/review-community.sh" "do_summary" "review-community.sh"
check_contains "scripts/review-community.sh" "gh pr list" "review-community.sh"
check_contains "scripts/review-community.sh" "gh issue list" "review-community.sh"
check_contains "scripts/review-community.sh" "gh pr diff" "review-community.sh"
check_contains "scripts/review-community.sh" "gh pr merge" "review-community.sh"
check_contains "scripts/review-community.sh" "gh release create" "review-community.sh"
check_contains "scripts/review-community.sh" "validate-commands" "review-community.sh"
check_contains "scripts/review-community.sh" "AKIA" "review-community.sh (secrets detection)"
check_contains "scripts/review-community.sh" "squash" "review-community.sh (merge strategy)"
check_contains "scripts/review-community.sh" "community" "review-community.sh (label)"

echo ""
echo "📋 Contenido de review-community.md (comando)"
check_contains ".claude/commands/review-community.md" "name: review-community" "review-community.md"
check_contains ".claude/commands/review-community.md" "pending" "review-community.md"
check_contains ".claude/commands/review-community.md" "review" "review-community.md"
check_contains ".claude/commands/review-community.md" "merge" "review-community.md"
check_contains ".claude/commands/review-community.md" "release" "review-community.md"
check_contains ".claude/commands/review-community.md" "summary" "review-community.md"
check_contains ".claude/commands/review-community.md" "Savia" "review-community.md"
check_contains ".claude/commands/review-community.md" "NUNCA" "review-community.md"
check_contains ".claude/commands/review-community.md" "maintainer" "review-community.md"

echo ""
echo "📖 Integración con CLAUDE.md"
check_contains "CLAUDE.md" "/review-community" "CLAUDE.md"
check_contains "CLAUDE.md" "commands/ (166)" "CLAUDE.md"

echo ""
echo "📖 Integración con README.md"
check_contains "README.md" "/review-community" "README.md"
check_contains "README.md" "166 comandos" "README.md"

echo ""
echo "📖 Integración con README.en.md"
check_contains "README.en.md" "/review-community" "README.en.md"
check_contains "README.en.md" "166 commands" "README.en.md"

echo ""
echo "📋 review-community.sh help funciona"
HELP_OUTPUT=$(cd "$WORKSPACE_DIR" && bash scripts/review-community.sh help 2>&1)
if echo "$HELP_OUTPUT" | grep -q "Comandos"; then
  pass "review-community.sh help muestra ayuda"
else
  fail "review-community.sh help NO muestra ayuda"
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
