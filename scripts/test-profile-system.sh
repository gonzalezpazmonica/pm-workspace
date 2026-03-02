#!/usr/bin/env bash
# ── test-profile-system.sh ─────────────────────────────────────────────────
# Tests para el User Profiling System de pm-workspace
# Uso: bash scripts/test-profile-system.sh
# ───────────────────────────────────────────────────────────────────────────

set -uo pipefail
cd "$(dirname "$0")/.."

PASS=0
FAIL=0
TOTAL=0

pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  ❌ $1"; }

test_file_exists() {
  if [[ -f "$1" ]]; then pass "Existe: $1"
  else fail "No existe: $1"; fi
}

test_dir_exists() {
  if [[ -d "$1" ]]; then pass "Dir existe: $1"
  else fail "Dir no existe: $1"; fi
}

test_contains() {
  if grep -q "$2" "$1" 2>/dev/null; then pass "Contiene '$2' en $(basename "$1")"
  else fail "No contiene '$2' en $1"; fi
}

test_not_empty() {
  if [[ -s "$1" ]]; then pass "No vacío: $(basename "$1")"
  else fail "Vacío: $1"; fi
}

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Test Suite: User Profiling System"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Categoría 1: Estructura de directorios ──────────────────────────────
echo ""
echo "📁 Estructura de directorios"
test_dir_exists  ".claude/profiles"
test_dir_exists  ".claude/profiles/users"
test_dir_exists  ".claude/profiles/users/template"

# ── Categoría 2: Ficheros estructurales ─────────────────────────────────
echo ""
echo "📄 Ficheros estructurales"
test_file_exists ".claude/profiles/README.md"
test_file_exists ".claude/profiles/active-user.md"
test_file_exists ".claude/profiles/context-map.md"

# ── Categoría 3: Template de usuario ────────────────────────────────────
echo ""
echo "📋 Template de usuario"
test_file_exists ".claude/profiles/users/template/identity.md"
test_file_exists ".claude/profiles/users/template/workflow.md"
test_file_exists ".claude/profiles/users/template/tools.md"
test_file_exists ".claude/profiles/users/template/projects.md"
test_file_exists ".claude/profiles/users/template/preferences.md"
test_file_exists ".claude/profiles/users/template/tone.md"

# ── Categoría 4: Comandos de perfil ────────────────────────────────────
echo ""
echo "🔧 Comandos de perfil"
test_file_exists ".claude/commands/profile-setup.md"
test_file_exists ".claude/commands/profile-edit.md"
test_file_exists ".claude/commands/profile-switch.md"
test_file_exists ".claude/commands/profile-show.md"

# ── Categoría 5: Contenido del context-map (table format) ─────────────────
echo ""
echo "🗺️  Contenido del context-map (table format)"
# Check for table headers (new format)
test_contains ".claude/profiles/context-map.md" "| Group | Commands | Load | Skip |"
# Check for group names (updated format)
test_contains ".claude/profiles/context-map.md" "Sprint Daily"
test_contains ".claude/profiles/context-map.md" "Reporting"
test_contains ".claude/profiles/context-map.md" "PBI & Backlog"
test_contains ".claude/profiles/context-map.md" "Spec & SDD"
test_contains ".claude/profiles/context-map.md" "Team & Skills"
test_contains ".claude/profiles/context-map.md" "Quality & PRs"
test_contains ".claude/profiles/context-map.md" "Infra & Pipelines"
test_contains ".claude/profiles/context-map.md" "Governance"
test_contains ".claude/profiles/context-map.md" "Messaging"
test_contains ".claude/profiles/context-map.md" "Connectors"
test_contains ".claude/profiles/context-map.md" "Memory & Context"
test_contains ".claude/profiles/context-map.md" "Diagrams"
test_contains ".claude/profiles/context-map.md" "Architecture & Tech"
test_contains ".claude/profiles/context-map.md" "Skip"

# ── Categoría 6: Contenido de comandos de perfil ───────────────────────
echo ""
echo "📝 Contenido de comandos"
test_contains ".claude/commands/profile-setup.md" "identity.md"
test_contains ".claude/commands/profile-setup.md" "workflow.md"
test_contains ".claude/commands/profile-setup.md" "tone.md"
test_contains ".claude/commands/profile-setup.md" "active-user.md"
test_contains ".claude/commands/profile-edit.md" "active_slug"
test_contains ".claude/commands/profile-switch.md" "active-user.md"
test_contains ".claude/commands/profile-show.md" "identity.md"

# ── Categoría 7: Perfil de test (sala-reservas) ────────────────────────
echo ""
echo "🧑 Perfil de test (test-user-sala)"
test_dir_exists  ".claude/profiles/users/test-user-sala"
test_file_exists ".claude/profiles/users/test-user-sala/identity.md"
test_file_exists ".claude/profiles/users/test-user-sala/workflow.md"
test_file_exists ".claude/profiles/users/test-user-sala/tools.md"
test_file_exists ".claude/profiles/users/test-user-sala/projects.md"
test_file_exists ".claude/profiles/users/test-user-sala/preferences.md"
test_file_exists ".claude/profiles/users/test-user-sala/tone.md"
test_contains ".claude/profiles/users/test-user-sala/identity.md" "Test User"
test_contains ".claude/profiles/users/test-user-sala/identity.md" "test-user-sala"
test_contains ".claude/profiles/users/test-user-sala/workflow.md" "daily-first"
test_contains ".claude/profiles/users/test-user-sala/tools.md" "azure_devops: true"
test_contains ".claude/profiles/users/test-user-sala/projects.md" "sala-reservas"
test_contains ".claude/profiles/users/test-user-sala/preferences.md" "language: \"es\""
test_contains ".claude/profiles/users/test-user-sala/tone.md" "alert_style: \"direct\""

# ── Categoría 8: Integración con CLAUDE.md ──────────────────────────────
echo ""
echo "🔗 Integración con CLAUDE.md"
test_contains "CLAUDE.md" "la voz de pm-workspace"
test_contains "CLAUDE.md" "active-user.md"
test_contains "CLAUDE.md" "context-map.md"
test_contains "CLAUDE.md" "profile-setup"
test_contains "CLAUDE.md" "profiles/"

# ── Categoría 9: Integración con .gitignore ─────────────────────────────
echo ""
echo "🔒 Integración con .gitignore"
test_contains ".gitignore" "profiles/users"
test_contains ".gitignore" "template"

# ── Categoría 10: Comandos existentes actualizados ──────────────────────
echo ""
echo "🔄 Comandos existentes con carga de perfil"

CMDS_TO_CHECK=(
  "sprint-status" "sprint-plan" "sprint-review" "sprint-retro"
  "report-hours" "report-executive" "report-capacity"
  "pbi-decompose" "pbi-assign" "pbi-plan-sprint"
  "spec-generate" "spec-implement" "agent-run"
  "team-workload" "board-flow"
  "pr-pending" "pr-review"
  "pipeline-create" "pipeline-status"
  "compliance-scan" "security-review"
  "notify-slack" "notify-whatsapp"
  "confluence-publish" "jira-sync"
  "memory-context" "memory-save"
  "diagram-generate" "diagram-import"
  "arch-detect" "debt-track"
)

for cmd in "${CMDS_TO_CHECK[@]}"; do
  if grep -q "Cargar perfil de usuario" ".claude/commands/${cmd}.md" 2>/dev/null; then
    pass "Perfil integrado en /${cmd}"
  else
    fail "Falta perfil en /${cmd}"
  fi
done

# ── Categoría 11: Trigger combinado (hook + regla) ──────────────────────
echo ""
echo "🔔 Trigger combinado (hook + regla)"
test_contains ".claude/hooks/session-init.sh" "active_slug"
test_contains ".claude/hooks/session-init.sh" "Perfil activo"
test_contains ".claude/hooks/session-init.sh" "profile-setup"
test_contains ".claude/hooks/session-init.sh" "identity.md"
test_file_exists ".claude/rules/domain/profile-onboarding.md"
test_contains ".claude/rules/domain/profile-onboarding.md" "active-user.md"
test_contains ".claude/rules/domain/profile-onboarding.md" "profile-setup"
test_contains ".claude/rules/domain/profile-onboarding.md" "identity.md"

# ── Categoría 12: Hook produce JSON válido ──────────────────────────────
echo ""
echo "⚙️  Hook produce JSON válido"
HOOK_OUTPUT=$(bash .claude/hooks/session-init.sh 2>/dev/null)
if echo "$HOOK_OUTPUT" | jq . >/dev/null 2>&1; then
  pass "session-init.sh produce JSON válido"
else
  fail "session-init.sh NO produce JSON válido"
fi
if echo "$HOOK_OUTPUT" | grep -q "SIN PERFIL\|Perfil activo"; then
  pass "Hook incluye estado del perfil en output"
else
  fail "Hook NO incluye estado del perfil"
fi

# ── Categoría 13: Savia — Identidad de pm-workspace ─────────────────────
echo ""
echo "🦉 Savia — Identidad de pm-workspace"
test_file_exists ".claude/profiles/savia.md"
test_contains ".claude/profiles/savia.md" "Savia"
test_contains ".claude/profiles/savia.md" "buhita"
test_contains ".claude/profiles/savia.md" "femenino"
test_contains ".claude/profiles/savia.md" "Primera impresión"
test_contains ".claude/profiles/savia.md" "Adaptación al perfil"
test_contains ".claude/rules/domain/profile-onboarding.md" "Savia"
test_contains ".claude/rules/domain/profile-onboarding.md" "savia.md"
test_contains ".claude/commands/profile-setup.md" "Savia"
test_contains ".claude/commands/profile-setup.md" "savia.md"
test_contains ".claude/commands/profile-setup.md" "Cómo te llamas"
test_contains ".claude/commands/profile-edit.md" "savia.md"
test_contains ".claude/commands/profile-switch.md" "savia.md"
test_contains ".claude/commands/profile-show.md" "savia.md"
test_contains "CLAUDE.md" "Savia"
test_contains ".claude/hooks/session-init.sh" "PERFIL\|profile\|Perfil"

# ── Categoría 14: Modo Agente ───────────────────────────────────────────
echo ""
echo "🤖 Modo Agente"
test_contains ".claude/profiles/savia.md" "Modo Agente"
test_contains ".claude/profiles/savia.md" "YAML"
test_contains ".claude/profiles/savia.md" "NO_PROFILE"
test_contains ".claude/profiles/savia.md" "output_format"
test_contains ".claude/profiles/savia.md" "Cero narrativa"
test_contains ".claude/profiles/savia.md" "status: OK"
test_contains ".claude/profiles/savia.md" "status: ERROR"
test_contains ".claude/rules/domain/profile-onboarding.md" "Modo Agente"
test_contains ".claude/rules/domain/profile-onboarding.md" "PM_CLIENT_TYPE"
test_contains ".claude/rules/domain/profile-onboarding.md" "AGENT_MODE"
test_contains ".claude/commands/profile-setup.md" "agente\|agent"
test_contains ".claude/commands/profile-setup.md" "role: \"Agent\""
test_contains ".claude/profiles/context-map.md" "role: \"Agent\""
test_contains ".claude/hooks/session-init.sh" "AGENT_MODE"
test_contains ".claude/hooks/session-init.sh" "PM_CLIENT_TYPE"

# ── Categoría 15: Hook detecta agente ───────────────────────────────────
echo ""
echo "⚙️  Hook detecta modo agente"
HOOK_AGENT=$(PM_CLIENT_TYPE=agent bash .claude/hooks/session-init.sh 2>/dev/null)
if echo "$HOOK_AGENT" | jq . >/dev/null 2>&1; then
  pass "Hook con PM_CLIENT_TYPE=agent produce JSON válido"
else
  fail "Hook con PM_CLIENT_TYPE=agent NO produce JSON válido"
fi
if echo "$HOOK_AGENT" | grep -q "AGENTE"; then
  pass "Hook detecta modo agente por variable de entorno"
else
  fail "Hook NO detecta modo agente"
fi

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resultado: ${PASS}/${TOTAL} tests passed (${FAIL} failed)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $FAIL -eq 0 ]]; then
  echo "✅ Todos los tests pasaron"
  exit 0
else
  echo "❌ Hay ${FAIL} test(s) fallidos"
  exit 1
fi
