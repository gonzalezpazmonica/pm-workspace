#!/bin/bash
# init-pm.sh — Carga variables de entorno de PM-Workspace para OpenCode
export PM_WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CLAUDE_PROJECT_DIR="$PM_WORKSPACE_ROOT"

# Función para cargar variables de un archivo .md
load_config() {
  local file="$1"
  [[ ! -f "$file" ]] && return
  while IFS='=' read -r key value; do
    key=$(echo "$key" | sed 's/[[:space:]]*$//')
    value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')
    [[ -n "$key" ]] && export "$key"="$value"
  done < <(grep -E '^[A-Z_]+[[:space:]]*=' "$file")
}

# Cargar configuración de CLAUDE.md (valores por defecto)
load_config "$PM_WORKSPACE_ROOT/CLAUDE.md"
# Sobrescribir con valores privados de CLAUDE.local.md si existe
load_config "$PM_WORKSPACE_ROOT/CLAUDE.local.md"

# Cargar PAT si existe
if [[ -f "$HOME/.azure/devops-pat" ]]; then
  export AZURE_DEVOPS_PAT_FILE="$HOME/.azure/devops-pat"
fi

echo "PM-Workspace variables cargadas. ORG_URL: ${AZURE_DEVOPS_ORG_URL:-no configurada}"