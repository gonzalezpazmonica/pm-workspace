#!/usr/bin/env bash
# stop-server.sh — Stop SaviaVaults server (Linux / macOS)
# Copyright (c) 2026 Savia. MIT License.
set -uo pipefail

VAULT_PATH="${1:-${SAVIA_VAULT_PATH:-$(pwd)}}"
PID_FILE="${VAULT_PATH}/.savia-vault/server.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "No server PID file found at $PID_FILE"
  # Try finding by process name
  PIDS=$(pgrep -f "savia-vaults serve" 2>/dev/null || true)
  if [[ -n "$PIDS" ]]; then
    echo "Found running processes: $PIDS"
    echo "Killing..."
    kill $PIDS 2>/dev/null || true
    echo "Stopped."
  else
    echo "No running SaviaVaults server found."
  fi
  exit 0
fi

PID=$(cat "$PID_FILE")
echo "Stopping SaviaVaults server (PID: $PID)..."

if kill -0 "$PID" 2>/dev/null; then
  kill "$PID" 2>/dev/null || true
  sleep 1
  if kill -0 "$PID" 2>/dev/null; then
    echo "Graceful stop failed. Force killing..."
    kill -9 "$PID" 2>/dev/null || true
  fi
  echo "Stopped."
else
  echo "Process $PID not running."
fi

rm -f "$PID_FILE"
