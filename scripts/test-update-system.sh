#!/bin/bash
# test-update-system.sh — Tests del sistema de actualización de pm-workspace
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
echo "🧪 Test Suite: Update System"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "📄 Ficheros del sistema de actualización"
check_file "scripts/update.sh" "scripts/update.sh"
check_executable "scripts/update.sh" "scripts/update.sh"
check_file ".claude/commands/update.md" ".claude/commands/update.md"

echo ""
echo "🔧 Contenido de scripts/update.sh"
check_contains "scripts/update.sh" "do_check" "update.sh"
check_contains "scripts/update.sh" "do_install" "update.sh"
check_contains "scripts/update.sh" "do_status" "update.sh"
check_contains "scripts/update.sh" "do_config" "update.sh"
check_contains "scripts/update.sh" "get_local_version" "update.sh"
check_contains "scripts/update.sh" "get_remote_version" "update.sh"
check_contains "scripts/update.sh" "verify_protected_data" "update.sh"
check_contains "scripts/update.sh" "PROTECTED_PATHS" "update.sh"
check_contains "scripts/update.sh" "git stash" "update.sh"
check_contains "scripts/update.sh" "fetch --tags" "update.sh"
check_contains "scripts/update.sh" "merge --abort" "update.sh"
check_contains "scripts/update.sh" "pm-workspace" "update.sh"

echo ""
echo "📋 Contenido de update.md (comando)"
check_contains ".claude/commands/update.md" "name: update" "update.md"
check_contains ".claude/commands/update.md" "check" "update.md"
check_contains ".claude/commands/update.md" "install" "update.md"
check_contains ".claude/commands/update.md" "auto-on" "update.md"
check_contains ".claude/commands/update.md" "auto-off" "update.md"
check_contains ".claude/commands/update.md" "status" "update.md"
check_contains ".claude/commands/update.md" "Savia" "update.md"
check_contains ".claude/commands/update.md" "context-map.md" "update.md"
check_contains ".claude/commands/update.md" "NUNCA" "update.md"
check_contains ".claude/commands/update.md" "Datos protegidos" "update.md"
check_contains ".claude/commands/update.md" "profiles/users" "update.md"
check_contains ".claude/commands/update.md" "YAML" "update.md"

echo ""
echo "🪝 Integración con session-init.sh"
check_contains ".claude/hooks/session-init.sh" "UPDATE_STATUS" "session-init.sh"
check_contains ".claude/hooks/session-init.sh" "update-config" "session-init.sh"
check_contains ".claude/hooks/session-init.sh" "auto_check" "session-init.sh"
check_contains ".claude/hooks/session-init.sh" "last_check" "session-init.sh"
check_contains ".claude/hooks/session-init.sh" "604800" "session-init.sh"
check_contains ".claude/hooks/session-init.sh" "releases/latest" "session-init.sh"
check_contains ".claude/hooks/session-init.sh" "/update" "session-init.sh"

echo ""
echo "📖 Integración con CLAUDE.md"
check_contains "CLAUDE.md" "/update" "CLAUDE.md"
check_contains "CLAUDE.md" "138 slash commands" "CLAUDE.md"

echo ""
echo "📖 Integración con README.md"
check_contains "README.md" "/update" "README.md"
check_contains "README.md" "138 comandos" "README.md"

echo ""
echo "📖 Integración con README.en.md"
check_contains "README.en.md" "/update" "README.en.md"
check_contains "README.en.md" "138 commands" "README.en.md"

echo ""
echo "⚙️  Hook produce JSON válido (con update check)"
HOOK_OUTPUT=$(cd "$WORKSPACE_DIR" && bash .claude/hooks/session-init.sh 2>/dev/null)
if echo "$HOOK_OUTPUT" | jq . >/dev/null 2>&1; then
  pass "session-init.sh produce JSON válido"
else
  fail "session-init.sh NO produce JSON válido"
fi
if echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q "PM-Workspace"; then
  pass "Hook incluye contexto PM-Workspace"
else
  fail "Hook NO incluye contexto PM-Workspace"
fi

echo ""
echo "🔒 Datos protegidos documentados"
for path in "profiles/users" "projects" "output" "CLAUDE.local.md" "decision-log.md" "pm-config.local.md"; do
  check_contains ".claude/commands/update.md" "$path" "update.md protección de $path"
  check_contains "scripts/update.sh" "$path" "update.sh protección de $path"
done

echo ""
echo "🧪 update.sh status funciona"
STATUS_OUTPUT=$(cd "$WORKSPACE_DIR" && bash scripts/update.sh status 2>&1)
if echo "$STATUS_OUTPUT" | grep -q "Versión actual"; then
  pass "update.sh status muestra versión"
else
  fail "update.sh status NO muestra versión"
fi
if echo "$STATUS_OUTPUT" | grep -q "Auto-check"; then
  pass "update.sh status muestra auto-check"
else
  fail "update.sh status NO muestra auto-check"
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
