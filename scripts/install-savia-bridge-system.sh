#!/usr/bin/env bash
# install-savia-bridge-system.sh — Promote savia-bridge to a SYSTEM systemd unit.
#
# Why this script exists:
#   The bridge must auto-start on host reboot (power failures, OS updates).
#   User-level systemd services only run while the user is logged in unless
#   `loginctl enable-linger` is set — either way, a system unit is the most
#   robust option.
#
# What this does (all under a single sudo session):
#   1. Stops the user-level savia-bridge.service if running
#   2. Disables the user unit and removes its default.target.wants symlink
#   3. Writes /etc/systemd/system/savia-bridge.service with correct paths
#   4. Creates /home/monica/.savia/bridge/ with monica:monica ownership
#   5. Reloads systemd, enables and starts the system unit
#   6. Verifies the /health endpoint
#
# Usage:
#   sudo bash scripts/install-savia-bridge-system.sh
#
# Safe to re-run: idempotent.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run with sudo" >&2
  exit 1
fi

USER_NAME="monica"
USER_HOME="/home/${USER_NAME}"
REPO_DIR="${USER_HOME}/claude"
BRIDGE_PY="${REPO_DIR}/scripts/savia-bridge.py"
SYSTEM_UNIT="/etc/systemd/system/savia-bridge.service"
USER_UNIT="${USER_HOME}/.config/systemd/user/savia-bridge.service"
STATE_DIR="${USER_HOME}/.savia/bridge"

echo "==> Preflight"
[[ -f "$BRIDGE_PY" ]] || { echo "ERROR: $BRIDGE_PY not found" >&2; exit 1; }
id "$USER_NAME" >/dev/null 2>&1 || { echo "ERROR: user $USER_NAME not found" >&2; exit 1; }

echo "==> Stopping and disabling user-level unit (if present)"
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u $USER_NAME)" \
  systemctl --user stop savia-bridge 2>/dev/null || true
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u $USER_NAME)" \
  systemctl --user disable savia-bridge 2>/dev/null || true
rm -f "${USER_HOME}/.config/systemd/user/default.target.wants/savia-bridge.service"

echo "==> Ensuring state dir exists"
install -d -o "$USER_NAME" -g "$USER_NAME" -m 0755 "$STATE_DIR"

echo "==> Writing $SYSTEM_UNIT (paths derived from USER_HOME=$USER_HOME)"
cat > "$SYSTEM_UNIT" <<EOF
[Unit]
Description=Savia Bridge — HTTPS bridge to Claude Code CLI
Documentation=file://${REPO_DIR}/scripts/savia-bridge.py
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${USER_NAME}
Group=${USER_NAME}
WorkingDirectory=${REPO_DIR}
ExecStart=/usr/bin/python3 ${REPO_DIR}/scripts/savia-bridge.py --port 8922 --host 0.0.0.0
Restart=on-failure
RestartSec=5
Environment=HOME=${USER_HOME}
Environment=PATH=${USER_HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin
StandardOutput=append:${STATE_DIR}/systemd.log
StandardError=append:${STATE_DIR}/systemd.log

# Security hardening
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
NoNewPrivileges=true
MemoryMax=512M
CPUQuota=50%
ReadWritePaths=${STATE_DIR}
ReadOnlyPaths=${REPO_DIR}

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 "$SYSTEM_UNIT"

echo "==> Reloading systemd"
systemctl daemon-reload

echo "==> Enabling and starting savia-bridge.service"
systemctl enable savia-bridge
systemctl restart savia-bridge

sleep 2
echo "==> Status"
systemctl status savia-bridge --no-pager -l | head -15 || true

echo "==> Health check"
if curl -sk --max-time 5 https://localhost:8922/health; then
  echo
  echo "✅ savia-bridge installed and healthy"
else
  echo
  echo "⚠️  health check failed — inspect: journalctl -u savia-bridge -n 50"
  exit 2
fi
