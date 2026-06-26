#!/usr/bin/env bats
# tests/bats/test-spec-installer-migration.bats — SPEC-INSTALLER-OPENCODE-MIGRATION
#
# Tests for the OpenCode installer migration:
#   - scripts/detect-frontend.sh
#   - docs/setup/frontend-migration-guide.md
#   - install.sh (OpenCode-first)
#   - .opencode/install.sh (no ~/claude hardcoded)
#
# Ref: docs/propuestas/SPEC-INSTALLER-OPENCODE-MIGRATION.md

REPO_ROOT="$(git rev-parse --show-toplevel)"
DETECT_SCRIPT="$REPO_ROOT/scripts/detect-frontend.sh"
MIGRATION_GUIDE="$REPO_ROOT/docs/setup/frontend-migration-guide.md"
INSTALL_SH="$REPO_ROOT/install.sh"
OPENCODE_INSTALL="$REPO_ROOT/.opencode/install.sh"

# ── Test 1: detect-frontend.sh existe y produce JSON valido ──────────────────
@test "detect-frontend.sh existe y es ejecutable" {
  [[ -f "$DETECT_SCRIPT" ]]
  [[ -x "$DETECT_SCRIPT" ]]
}

# ── Test 2: detect-frontend.sh produce JSON valido ───────────────────────────
@test "detect-frontend.sh produce JSON valido" {
  # Ejecutar (puede fallar con exit 1 si no hay frontend, pero siempre produce JSON)
  run bash "$DETECT_SCRIPT" || true
  # Verificar que el output (antes del exit code) es JSON valido
  json_output="$(bash "$DETECT_SCRIPT" 2>/dev/null || true)"
  [[ -n "$json_output" ]]
  echo "$json_output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

# ── Test 3: JSON tiene campo recommended ─────────────────────────────────────
@test "detect-frontend.sh JSON contiene campo 'recommended'" {
  json_output="$(bash "$DETECT_SCRIPT" 2>/dev/null || true)"
  echo "$json_output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'recommended' in d, 'Missing field: recommended'
assert d['recommended'] in ('opencode', 'claude_code', 'codex', 'none'), \
    f\"recommended={d['recommended']}, must be opencode|claude_code|codex|none\"
print('OK: recommended =', d['recommended'])
"
}

# ── Test 4: JSON tiene campos opencode, claude_code, codex, version ──────────
@test "detect-frontend.sh JSON tiene todos los campos requeridos" {
  json_output="$(bash "$DETECT_SCRIPT" 2>/dev/null || true)"
  echo "$json_output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
required = {'opencode', 'claude_code', 'codex', 'cursor', 'recommended', 'version'}
missing = required - d.keys()
assert not missing, f'Missing fields: {missing}'
assert isinstance(d['version'], dict), 'version must be a dict'
print('OK: all required fields present')
"
}

# ── Test 5: migration-guide.md existe y menciona opencode ────────────────────
@test "frontend-migration-guide.md existe y menciona opencode" {
  [[ -f "$MIGRATION_GUIDE" ]]
  grep -qi "opencode" "$MIGRATION_GUIDE"
}

# ── Test 6: install.sh no hardcodea ~/claude como unico path ─────────────────
@test "install.sh no tiene SAVIA_HOME hardcodeado en ~/claude" {
  [[ -f "$INSTALL_SH" ]]
  # El instalador principal NO debe tener ~/claude como default
  # (puede mencionarlo como fallback para usuarios existentes, pero no como default)
  run grep -c 'SAVIA_HOME=.*claude' "$INSTALL_SH"
  # Permitimos 0 o que aparezca solo como mencion de migracion (no como default)
  # La linea critica es la asignacion del default
  ! grep -qE 'SAVIA_HOME="\$\{SAVIA_HOME:-\$HOME/claude\}"' "$INSTALL_SH"
}

# ── Test 7: .opencode/install.sh no tiene SAVIA_HOME default en ~/claude ─────
@test ".opencode/install.sh no tiene SAVIA_HOME default en ~/claude" {
  [[ -f "$OPENCODE_INSTALL" ]]
  ! grep -qE 'SAVIA_HOME="\$\{SAVIA_HOME:-\$HOME/claude\}"' "$OPENCODE_INSTALL"
}

# ── Test 8: detect-frontend.sh detecta opencode correctamente ────────────────
@test "detect-frontend.sh detecta opencode si esta instalado" {
  json_output="$(bash "$DETECT_SCRIPT" 2>/dev/null || true)"
  oc_detected=$(echo "$json_output" | python3 -c "import json,sys; print(json.load(sys.stdin)['opencode'])")
  # El valor debe ser True si opencode esta en PATH, False si no
  if command -v opencode &>/dev/null; then
    [[ "$oc_detected" == "True" ]]
  else
    [[ "$oc_detected" == "False" ]]
  fi
}
