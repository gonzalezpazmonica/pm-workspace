#!/usr/bin/env bash
# vaults-introspect.sh — Introspect a SaviaVaults vault
# Usage: bash scripts/vaults-introspect.sh [--path <dir>] [--entity <path>] [--json]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_PATH=""
ENTITY_PATH=""
JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path) VAULT_PATH="$2"; shift 2 ;;
    --entity) ENTITY_PATH="$2"; shift 2 ;;
    --json) JSON=true; shift ;;
    *) shift ;;
  esac
done

SAVIA_VAULTS_DIR="$ROOT/projects/savia-vaults"

if command -v node &>/dev/null && [[ -f "$SAVIA_VAULTS_DIR/dist/cli/index.js" ]]; then
  if [[ -n "$ENTITY_PATH" ]]; then
    node "$SAVIA_VAULTS_DIR/dist/cli/index.js" introspect --path "${VAULT_PATH:-.}" --entity "$ENTITY_PATH" ${JSON:+--json}
  else
    node "$SAVIA_VAULTS_DIR/dist/cli/index.js" introspect --path "${VAULT_PATH:-.}" ${JSON:+--json}
  fi
else
  # Fallback: basic file listing
  echo "Vault: ${VAULT_PATH:-unknown}"
  echo "Documents: $(find "${VAULT_PATH:-.}" -name '*.md' -not -path '*/.git/*' 2>/dev/null | wc -l)"
  echo "Schema types: (build SaviaVaults first)"
fi
