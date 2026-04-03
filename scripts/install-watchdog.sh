#!/usr/bin/env bash
set -euo pipefail
# install-watchdog.sh — Installs savia-watchdog as systemd service
# Usage: sudo bash scripts/install-watchdog.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/savia-watchdog.service"
DEST="/etc/systemd/system/savia-watchdog.service"

if [[ $EUID -ne 0 ]]; then
  echo "Error: run with sudo"
  echo "  sudo bash $0"
  exit 1
fi

cp "$SERVICE_FILE" "$DEST"
systemctl daemon-reload
systemctl enable savia-watchdog
systemctl start savia-watchdog

echo "savia-watchdog installed and running"
echo "  Status:  systemctl status savia-watchdog"
echo "  Logs:    cat /tmp/savia-watchdog/watchdog.log"
echo "  Stop:    sudo systemctl stop savia-watchdog"
echo "  Config:  edit $DEST [Environment lines]"
