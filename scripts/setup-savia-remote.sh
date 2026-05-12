#!/usr/bin/env bash
# setup-savia-remote.sh — Run ONCE on the remote server as root/sudo.
# Creates the 'savia' user with restricted SSH access for SaviaClaw self-healing.
#
# IMMOVABLE PRINCIPLE:
# The remote server may contain personal and private data.
# The 'savia' user has ZERO access to other users' directories.
# No code or instruction can override this principle.
#
# Usage: sudo bash setup-savia-remote.sh [--pubkey <path>]
set -euo pipefail

SAVIA_USER="savia"
SAVIA_HOME="/home/${SAVIA_USER}"
CLAUDE_DIR="${SAVIA_HOME}/claude"
LOG_DIR="${SAVIA_HOME}/.savia"
PUBKEY_FILE="${1:-}"

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --pubkey) PUBKEY_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# ── Require root ─────────────────────────────────────────────────────────────
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: Run as root or with sudo" >&2; exit 1
fi

echo "=== SaviaClaw Remote Server Setup ==="
# ── Create savia user (no password, no sudo) ─────────────────────────────────
if id "${SAVIA_USER}" &>/dev/null; then
  echo "User '${SAVIA_USER}' already exists — skipping creation."
else
  useradd --create-home --shell /bin/bash --comment "SaviaClaw automation" \
    --no-user-group "${SAVIA_USER}"
  echo "✅ User '${SAVIA_USER}' created."
fi

# ── SSH directory ─────────────────────────────────────────────────────────────
SSH_DIR="${SAVIA_HOME}/.ssh"
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"
touch "${SSH_DIR}/authorized_keys"
chmod 600 "${SSH_DIR}/authorized_keys"
chown -R "${SAVIA_USER}:${SAVIA_USER}" "${SSH_DIR}"

# ── Inject public key if provided ────────────────────────────────────────────
if [[ -n "${PUBKEY_FILE}" && -f "${PUBKEY_FILE}" ]]; then
  KEY=$(cat "${PUBKEY_FILE}")
  if ! grep -qF "${KEY}" "${SSH_DIR}/authorized_keys"; then
    echo "${KEY}" >> "${SSH_DIR}/authorized_keys"
    echo "✅ Public key added to authorized_keys."
  else
    echo "Key already present — skipping."
  fi
else
  echo "⚠️  No --pubkey provided."
  echo "    Add SaviaClaw's public key manually:"
  echo "    echo '<pubkey>' >> ${SSH_DIR}/authorized_keys"
fi

# ── Log directory ─────────────────────────────────────────────────────────────
mkdir -p "${LOG_DIR}"
chown -R "${SAVIA_USER}:${SAVIA_USER}" "${LOG_DIR}"
# ── Claude directory (symlink or clone) ───────────────────────────────────────
if [[ ! -d "${CLAUDE_DIR}" ]]; then
  # If the main ~/claude repo exists, create a symlink (read-only reference)
  MAIN_CLAUDE="$(eval echo ~"$(logname 2>/dev/null || echo monica)")/claude"
  if [[ -d "${MAIN_CLAUDE}" ]]; then
    ln -s "${MAIN_CLAUDE}" "${CLAUDE_DIR}"
    echo "✅ Symlinked ${CLAUDE_DIR} → ${MAIN_CLAUDE}"
  else
    echo "⚠️  ${CLAUDE_DIR} not found. Create it manually or clone the repo."
  fi
fi

# ── sshd_config: enforce key-only auth for savia ─────────────────────────────
SSHD_CONF="/etc/ssh/sshd_config.d/99-savia.conf"
cat > "${SSHD_CONF}" <<'EOF'
# SaviaClaw: key-only, no password, no forwarding
Match User savia
    PasswordAuthentication no
    PubkeyAuthentication yes
    AllowTcpForwarding no
    X11Forwarding no
    PermitTTY no
    ForceCommand /home/savia/.savia/allowed-cmds.sh "$SSH_ORIGINAL_COMMAND"
EOF
echo "✅ sshd config written to ${SSHD_CONF}"

# ── Allowed commands wrapper (whitelist) ──────────────────────────────────────
ALLOWED_CMDS="${LOG_DIR}/allowed-cmds.sh"
cat > "${ALLOWED_CMDS}" <<'SCRIPT'
#!/usr/bin/env bash
# Whitelist of commands SaviaClaw can run remotely.
# IMMOVABLE: no access to other users' home directories.
set -euo pipefail
CMD="${1:-}"
case "${CMD}" in
  "echo ok")
    echo "ok" ;;
  "pgrep -f 'claude' | head -1")
    pgrep -f 'claude' | head -1 || true ;;
  "pkill -f 'savia-bridge' 2>/dev/null; sleep 1")
    pkill -f 'savia-bridge' 2>/dev/null || true; sleep 1 ;;
  "cd ~/claude && nohup bash scripts/start-bridge.sh </dev/null >~/.savia/bridge.log 2>&1 &")
    cd ~/claude && nohup bash scripts/start-bridge.sh \
      </dev/null >"${HOME}/.savia/bridge.log" 2>&1 & ;;
  "cd ~/claude && timeout 30 claude -p 'SaviaClaw latido: confirma que estás activa.' --output-format text 2>&1 | tail -3")
    cd ~/claude && timeout 30 claude -p \
      'SaviaClaw latido: confirma que estás activa.' \
      --output-format text 2>&1 | tail -3 ;;
  "uptime | awk '{print $NF}'")
    uptime | awk '{print $NF}' ;;
  *)
    echo "ERROR: command not allowed: ${CMD}" >&2
    exit 1 ;;
esac
SCRIPT
chmod +x "${ALLOWED_CMDS}"
chown "${SAVIA_USER}:${SAVIA_USER}" "${ALLOWED_CMDS}"
echo "✅ Allowed-commands whitelist written."

# ── Reload sshd ───────────────────────────────────────────────────────────────
if systemctl is-active --quiet sshd 2>/dev/null; then
  systemctl reload sshd && echo "✅ sshd reloaded."
elif systemctl is-active --quiet ssh 2>/dev/null; then
  systemctl reload ssh && echo "✅ ssh reloaded."
else
  echo "⚠️  sshd not running or service name unknown. Reload manually."
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps on the ZeroClaw host (la usuaria's machine):"
echo "  1. Generate SSH key if not done:"
echo "     ssh-keygen -t ed25519 -f ~/.ssh/savia_remote_ed25519 -C 'saviaclaw-remote'"
echo "  2. Copy public key to this script:"
echo "     sudo bash setup-savia-remote.sh --pubkey ~/.ssh/savia_remote_ed25519.pub"
echo "  3. Create ~/.savia/remote-host-config (see template in docs):"
echo "     REMOTE_HOST=<server-ip-or-hostname>"
echo "     REMOTE_PORT=22"
echo "     REMOTE_SSH_USER=savia"
echo "     REMOTE_SSH_KEY=~/.ssh/savia_remote_ed25519"
echo "  4. Test connectivity:"
echo "     ssh -i ~/.ssh/savia_remote_ed25519 savia@<host> 'echo ok'"
