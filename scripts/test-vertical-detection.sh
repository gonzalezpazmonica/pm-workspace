#!/bin/bash
# test-vertical-detection.sh — Tests del sistema de detección de verticales
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

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Test Suite: Vertical Detection System"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "📄 Ficheros del sistema de verticales"
check_file ".claude/rules/domain/vertical-detection.md" "vertical-detection.md"
check_file ".claude/commands/vertical-propose.md" "vertical-propose.md"

echo ""
echo "🔧 Contenido de vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "Fase 1" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "Fase 2" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "Fase 3" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "Fase 4" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "Fase 5" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "35%" "vertical-detection.md (peso fase 1)"
check_contains ".claude/rules/domain/vertical-detection.md" "25%" "vertical-detection.md (peso fase 2)"
check_contains ".claude/rules/domain/vertical-detection.md" "15%" "vertical-detection.md (peso fase 3)"
check_contains ".claude/rules/domain/vertical-detection.md" "Healthcare" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "Legal" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "Industrial" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "Agriculture" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "Education" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "Finance" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "55%" "vertical-detection.md (scoring threshold)"
check_contains ".claude/rules/domain/vertical-detection.md" "validate_privacy" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "Patient" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "hl7-fhir" "vertical-detection.md"
check_contains ".claude/rules/domain/vertical-detection.md" "HIPAA" "vertical-detection.md"

echo ""
echo "📋 Contenido de vertical-propose.md"
check_contains ".claude/commands/vertical-propose.md" "name: vertical-propose" "vertical-propose.md"
check_contains ".claude/commands/vertical-propose.md" "5 fases" "vertical-propose.md"
check_contains ".claude/commands/vertical-propose.md" "vertical-detection.md" "vertical-propose.md"
check_contains ".claude/commands/vertical-propose.md" "contribute" "vertical-propose.md"
check_contains ".claude/commands/vertical-propose.md" "Savia" "vertical-propose.md"
check_contains ".claude/commands/vertical-propose.md" "NUNCA" "vertical-propose.md"
check_contains ".claude/commands/vertical-propose.md" "rules.md" "vertical-propose.md"
check_contains ".claude/commands/vertical-propose.md" "workflows.md" "vertical-propose.md"
check_contains ".claude/commands/vertical-propose.md" "entities.md" "vertical-propose.md"
check_contains ".claude/commands/vertical-propose.md" "compliance.md" "vertical-propose.md"

echo ""
echo "🪝 Integración con profile-onboarding.md"
check_contains ".claude/rules/domain/profile-onboarding.md" "vertical" "profile-onboarding.md"
check_contains ".claude/rules/domain/profile-onboarding.md" "vertical-detection.md" "profile-onboarding.md"
check_contains ".claude/rules/domain/profile-onboarding.md" "vertical-propose" "profile-onboarding.md"

echo ""
echo "📖 Integración con CLAUDE.md"
check_contains "CLAUDE.md" "/vertical-propose" "CLAUDE.md"
check_contains "CLAUDE.md" "commands/ (146)" "CLAUDE.md"

echo ""
echo "📖 Integración con README.md"
check_contains "README.md" "/vertical-propose" "README.md"
check_contains "README.md" "146 comandos" "README.md"
check_contains "README.md" "verticales" "README.md"

echo ""
echo "📖 Integración con README.en.md"
check_contains "README.en.md" "/vertical-propose" "README.en.md"
check_contains "README.en.md" "146 commands" "README.en.md"
check_contains "README.en.md" "Vertical" "README.en.md"

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
