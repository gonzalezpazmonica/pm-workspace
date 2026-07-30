#!/usr/bin/env bash
# start-server.sh — Start SaviaVaults server (Linux / macOS)
# Copyright (c) 2026 Savia. MIT License.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_PATH="${1:-${SAVIA_VAULT_PATH:-$(pwd)}}"
TRANSPORT="${SAVIA_TRANSPORT:-mcp}"
PORT="${SAVIA_PORT:-8923}"
LOG_FILE="${SAVIA_LOG_FILE:-${VAULT_PATH}/.savia-vault/server.log}"
PID_FILE="${VAULT_PATH}/.savia-vault/server.pid"

mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")"

if [[ -f "$PID_FILE" ]]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "Server already running (PID: $OLD_PID). Use stop-server.sh to stop first."
    exit 1
  fi
  rm -f "$PID_FILE"
fi

echo "Starting SaviaVaults server..."
echo "  Vault:    $VAULT_PATH"
echo "  Transport: $TRANSPORT"
[[ "$TRANSPORT" == "a2a" ]] && echo "  Port:     $PORT"
echo "  Log:      $LOG_FILE"

if [[ "$TRANSPORT" == "mcp" ]]; then
  nohup npx savia-vaults serve --transport mcp --path "$VAULT_PATH" --name "$(basename "$VAULT_PATH")" > "$LOG_FILE" 2>&1 &
elif [[ "$TRANSPORT" == "a2a" ]]; then
  nohup npx savia-vaults serve --transport a2a --port "$PORT" --path "$VAULT_PATH" --name "$(basename "$VAULT_PATH")" > "$LOG_FILE" 2>&1 &
else
  echo "Unknown transport: $TRANSPORT. Use 'mcp' or 'a2a'."
  exit 1
fi

PID=$!
echo $PID > "$PID_FILE"
sleep 1

if kill -0 "$PID" 2>/dev/null; then
  echo "Server started (PID: $PID)"
else
  echo "Server failed to start. Check log: $LOG_FILE"
  rm -f "$PID_FILE"
  exit 1
fi
