#!/usr/bin/env bash
# start-bridge.sh — Invoked by Savia Claw remote_host.restart_bridge()
# Restarts the Savia Bridge systemd service (user unit for now, system unit after install).
set -uo pipefail

LOG_FILE="$HOME/.savia/bridge/start-bridge.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "[$(date -Iseconds)] $*" >> "$LOG_FILE"; }

log "start-bridge called"

# Prefer system service if installed, fall back to user service.
if systemctl list-unit-files 2>/dev/null | grep -q '^savia-bridge\.service'; then
  log "system unit found — restarting via sudo systemctl"
  if sudo -n systemctl restart savia-bridge 2>>"$LOG_FILE"; then
    log "system unit restarted OK"
    echo "savia-bridge restarted (system)"
    exit 0
  fi
  log "sudo restart failed — falling through"
fi

# User service fallback (works while monica is logged in or linger enabled)
if systemctl --user list-unit-files 2>/dev/null | grep -q '^savia-bridge\.service'; then
  log "user unit found — restarting via systemctl --user"
  if systemctl --user restart savia-bridge 2>>"$LOG_FILE"; then
    log "user unit restarted OK"
    echo "savia-bridge restarted (user)"
    exit 0
  fi
  log "user restart failed"
fi

log "no savia-bridge unit available"
echo "ERROR: no savia-bridge.service installed" >&2
exit 1
