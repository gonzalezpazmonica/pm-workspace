#!/bin/bash
# test-utils.sh — Funciones compartidas para todos los test scripts
# Proporciona utilidades para validaciones dinámicas sin hardcoding

set -uo pipefail

# ── Contadores dinámicos ──────────────────────────────────────────────────────

get_actual_command_count() {
  ls -1 .opencode/commands/*.md 2>/dev/null | wc -l
}

check_command_count_in_claude_md() {
  local actual_count=$(get_actual_command_count)
  local file="${1:-CLAUDE.md}"

  # Buscar "commands/ (N)" donde N es el número actual
  if grep -q "commands/ ($actual_count)" "$file" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

check_command_count_in_readme() {
  local actual_count=$(get_actual_command_count)
  local file="${1:-README.md}"
  local pattern="${2:-%s comando}" # patrón con %s para el número

  local expected_text=$(printf "$pattern" "$actual_count")
  if grep -q "$expected_text" "$file" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# ── Funciones estándar de testing ──────────────────────────────────────────────

pass() {
  ((PASS++))
  echo "  ✅ $1"
}

fail() {
  ((FAIL++))
  ERRORS+="  ❌ $1\n"
  echo "  ❌ $1"
}

check_file() {
  [ -f "$1" ] && pass "$2" || fail "$2"
}

check_content() {
  grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"
}

check_contains() {
  local file="${WORKSPACE_DIR:-$(pwd)}/$1"
  local pattern="$2"
  local label="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    pass "Contiene '$pattern' en $label"
  else
    fail "No contiene '$pattern' en $label"
  fi
}

# ── Node.js utilities ─────────────────────────────────────────────────────────

check_node_installed() {
  if command -v node &>/dev/null; then
    return 0
  else
    return 1
  fi
}

warn_node_not_installed() {
  echo "⚠️  Node.js no encontrado. Saltando validación de dependencias Node.js..."
}

# ── Helper para validar que count se actualiza dinámicamente ──────────────────

validate_dynamic_count() {
  local file="$1"
  local expected_count=$(get_actual_command_count)

  if grep -q "commands/ ($expected_count)" "$file" 2>/dev/null; then
    pass "CLAUDE.md tiene count dinámico correcto: $expected_count"
    return 0
  else
    fail "CLAUDE.md no coincide. Esperado: $expected_count"
    return 1
  fi
}
