#!/usr/bin/env bash
# vaults-graph-query.sh — Knowledge graph queries via SaviaVaults
# Usage: bash scripts/vaults-graph-query.sh --vault <name> --traverse <id> [--depth 3]
#        bash scripts/vaults-graph-query.sh --vault <name> --query "Entity.property"
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT/config/vaults.yaml"
SAVIA_VAULTS_DIR="$ROOT/projects/savia-vaults"
VAULT_NAME=""
MODE=""
TRAVERSE_ID=""
DEPTH=3
QUERY_EXPR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_NAME="$2"; shift 2 ;;
    --traverse) MODE="traverse"; TRAVERSE_ID="$2"; shift 2 ;;
    --query) MODE="query"; QUERY_EXPR="$2"; shift 2 ;;
    --depth) DEPTH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

VAULT_PATH=$(grep -A5 "^  ${VAULT_NAME}:" "$CONFIG_FILE" 2>/dev/null | grep "path:" | head -1 | sed 's/.*path: *//;s/"//g' | xargs)
[[ -n "$VAULT_PATH" ]] && VAULT_PATH="$ROOT/$VAULT_PATH"

if [[ -z "$VAULT_PATH" ]]; then
  echo "ERROR: Unknown vault: ${VAULT_NAME:-unspecified}"
  exit 1
fi

if [[ ! -f "$SAVIA_VAULTS_DIR/dist/cli/index.js" ]]; then
  echo "DEGRADED: SaviaVaults not built. Run: cd projects/savia-vaults && npm run build"
  exit 0
fi

SCHEMA_DIR=$(grep -A5 "^  ${VAULT_NAME}:" "$CONFIG_FILE" | grep "schema_dir:" | head -1 | sed 's/.*schema_dir: *//;s/"//g' | xargs)

case "$MODE" in
  traverse)
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    cd "$SAVIA_VAULTS_DIR" && node dist/cli/index.js graph --path "$VAULT_PATH" --action traverse --id "$TRAVERSE_ID" --depth "$DEPTH"
    ;;
  query)
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    cd "$SAVIA_VAULTS_DIR" && node dist/cli/index.js query "$QUERY_EXPR" --path "$VAULT_PATH"
    ;;
  *)
    echo "Usage: $0 --vault <name> [--traverse <id>|--query <expr>]"
    ;;
esac
