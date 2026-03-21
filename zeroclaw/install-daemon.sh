#!/usr/bin/env bash
# Install SaviaClaw daemon as systemd service
# Usage: sudo bash zeroclaw/install-daemon.sh
set -euo pipefail

SERVICE_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/host/saviaclaw.service"
DEST="/etc/systemd/system/saviaclaw.service"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo bash zeroclaw/install-daemon.sh"
    exit 1
fi

echo "Installing SaviaClaw daemon..."
cp "$SERVICE_FILE" "$DEST"
systemctl daemon-reload
systemctl enable saviaclaw
systemctl start saviaclaw
echo "SaviaClaw daemon installed and running."
echo "  Status: systemctl status saviaclaw"
echo "  Logs:   journalctl -u saviaclaw -f"
echo "  Stop:   sudo systemctl stop saviaclaw"
