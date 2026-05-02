#!/bin/bash
# init-pm.sh — Carga variables core de PM-Workspace para OpenCode.
# Azure DevOps, Jira, Savia Flow y otros backends se cargan BAJO DEMANDA
# por proyecto. NO son parte de la identidad core de Savia.
export PM_WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CLAUDE_PROJECT_DIR="$PM_WORKSPACE_ROOT"

# -- Funciones de carga opcional bajo demanda --

load_config() {
  local file="$1"
  [[ ! -f "$file" ]] && return
  while IFS='=' read -r key value; do
    key=$(echo "$key" | sed 's/[[:space:]]*$//')
    value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')
    [[ -n "$key" ]] && export "$key"="$value"
  done < <(grep -E '^[A-Z_]+[[:space:]]*=' "$file")
}

is_placeholder() {
  local val="$1"
  [[ "$val" =~ MI[_-]?ORGANIZA(CION|CIÓN|TION) ]] && return 0
  [[ "$val" =~ TU[_-]?ORGANIZA(CION|CIÓN|TION) ]] && return 0
  [[ "$val" =~ YOUR[_-]?ORGANIZA(TION)? ]] && return 0
  return 1
}

# -- Backends opcionales (Azure DevOps, Jira, etc.) --
# Solo se cargan si están configurados con valores reales (no placeholders).
# Los placeholders indican "no configurado" — el backend se activa bajo demanda
# cuando un proyecto lo requiere.

load_backend_config() {
  local config_file="$1"
  local loaded=0

  load_config "$config_file"

  if [[ -n "$AZURE_DEVOPS_ORG_URL" ]] && ! is_placeholder "$AZURE_DEVOPS_ORG_URL"; then
    if [[ -f "$HOME/.azure/devops-pat" ]]; then
      export AZURE_DEVOPS_PAT_FILE="$HOME/.azure/devops-pat"
    fi
    loaded=$((loaded + 1))
  else
    unset AZURE_DEVOPS_ORG_URL AZURE_DEVOPS_PAT_FILE AZURE_DEVOPS_API_VERSION AZURE_DEVOPS_PM_USER SPRINT_DURATION_WEEKS 2>/dev/null
  fi

  return $loaded
}

# Cargar config base
load_backend_config "$PM_WORKSPACE_ROOT/CLAUDE.md"
# Sobrescribir con valores privados si existen
load_backend_config "$PM_WORKSPACE_ROOT/CLAUDE.local.md" 2>/dev/null

# -- Banner informativo --

echo "PM-Workspace core cargado. Backends:"
echo "  Azure DevOps: ${AZURE_DEVOPS_ORG_URL:-no configurado (opcional, bajo demanda)}"
