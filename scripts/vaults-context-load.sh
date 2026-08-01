#!/usr/bin/env bash
# vaults-context-load.sh — Context loading via SaviaVaults with fallback
# Usage: bash scripts/vaults-context-load.sh --vault <name> [--query <term>] [--max-results <n>]
#        bash scripts/vaults-context-load.sh --vault <name> --read <path>
#        bash scripts/vaults-context-load.sh --vault <name> --stats
#        bash scripts/vaults-context-load.sh --vault <name> --diff <path>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT/config/vaults.yaml"
SAVIA_VAULTS_DIR="$ROOT/projects/savia-vaults"
MODE=""
VAULT_NAME=""
QUERY=""
MAX_RESULTS=10
READ_PATH=""
DIFF_PATH=""
USE_VAULTS=false
DEGRADED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_NAME="$2"; shift 2 ;;
    --query) MODE="search"; QUERY="$2"; shift 2 ;;
    --read) MODE="read"; READ_PATH="$2"; shift 2 ;;
    --stats) MODE="stats"; shift ;;
    --diff) MODE="diff"; DIFF_PATH="$2"; shift 2 ;;
    --max-results) MAX_RESULTS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Resolve vault path from config
VAULT_PATH=""
if [[ -n "$VAULT_NAME" && -f "$CONFIG_FILE" ]]; then
  # Simple YAML path extraction
  VAULT_PATH=$(grep -A5 "^  ${VAULT_NAME}:" "$CONFIG_FILE" | grep "path:" | head -1 | sed 's/.*path: *//;s/"//g' | xargs)
  [[ -n "$VAULT_PATH" ]] && VAULT_PATH="$ROOT/$VAULT_PATH"
fi

if [[ -z "$VAULT_PATH" ]]; then
  echo "ERROR: Unknown vault: ${VAULT_NAME:-unspecified}"
  echo "Declared vaults:"
  grep "^  [a-z]" "$CONFIG_FILE" 2>/dev/null | sed 's/:.*//;s/^/  - /' || echo "  (no config file)"
  exit 1
fi

# Check if SaviaVaults CLI is available
if command -v node &>/dev/null && [[ -f "$SAVIA_VAULTS_DIR/dist/cli/index.js" ]]; then
  USE_VAULTS=true
else
  DEGRADED=true
fi

if $DEGRADED; then
  echo "DEGRADED: SaviaVaults not available — using direct filesystem access"
fi

case "$MODE" in
  search)
    if $USE_VAULTS; then
      node "$SAVIA_VAULTS_DIR/dist/cli/index.js" search "$QUERY" --path "$VAULT_PATH" --json 2>/dev/null
    else
      echo "Searching: $QUERY in $VAULT_PATH"
      grep -rl "$QUERY" "$VAULT_PATH" --include="*.md" 2>/dev/null | head -"$MAX_RESULTS" || echo "(no results)"
    fi
    ;;

  read)
    if $USE_VAULTS; then
      if [[ -f "$VAULT_PATH/$READ_PATH" ]]; then
        cat "$VAULT_PATH/$READ_PATH"
      else
        echo "ERROR: $READ_PATH not found in $VAULT_PATH"
        exit 1
      fi
    else
      [[ -f "$VAULT_PATH/$READ_PATH" ]] && cat "$VAULT_PATH/$READ_PATH" || echo "(not found)"
    fi
    ;;

  stats)
    if $USE_VAULTS; then
      node "$SAVIA_VAULTS_DIR/dist/cli/index.js" stats --path "$VAULT_PATH" --json 2>/dev/null
    else
      echo "{"
      echo "  \"name\": \"$VAULT_NAME\","
      echo "  \"noteCount\": $(find "$VAULT_PATH" -name '*.md' -not -path '*/.git/*' 2>/dev/null | wc -l),"
      echo "  \"degraded\": true"
      echo "}"
    fi
    ;;

  diff)
    if [[ -f "$VAULT_PATH/$DIFF_PATH" ]]; then
      if $USE_VAULTS; then
        # Use vault_diff via CLI
        node "$SAVIA_VAULTS_DIR/dist/cli/index.js" search "diff" --path "$VAULT_PATH" --json 2>/dev/null | head -5
      else
        (cd "$VAULT_PATH" && git log --oneline -5 -- "$DIFF_PATH" 2>/dev/null) || echo "(no git history)"
      fi
    else
      echo "ERROR: $DIFF_PATH not found in $VAULT_PATH"
    fi
    ;;

  *)
    echo "Usage: $0 --vault <name> [--query <term>|--read <path>|--stats|--diff <path>]"
    echo "Declared vaults:"
    grep "^  [a-z]" "$CONFIG_FILE" 2>/dev/null | sed 's/:.*//;s/^/  - /'
    ;;
esac
