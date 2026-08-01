#!/usr/bin/env bash
# vaults-backup-cron.sh — Cron job: backup SaviaLabs + sync to Nextcloud
# Intended to be called from crontab. Loads credentials and runs backup.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$HOME/.savia-vaults/logs"
CONFIG_FILE="$HOME/.savia-vaults/nextcloud.env"
VAULT_PATH="$ROOT/vaults/SaviaLabs"
LABS_PATH="$ROOT/labs"

mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/backup-$(date +%Y%m%d-%H%M%S).log"

exec 1> >(tee -a "$LOG")
exec 2>&1

echo "=== SaviaVaults Backup — $(date) ==="

# Load Nextcloud config if exists
if [[ -f "$CONFIG_FILE" ]]; then
  set -a; source "$CONFIG_FILE"; set +a
  echo "Nextcloud config loaded."
else
  echo "Nextcloud not configured. Run: bash scripts/vaults-nextcloud-setup.sh"
fi

# Build SaviaVaults if needed
VAULTS_DIR="$ROOT/projects/savia-vaults"
if [[ ! -f "$VAULTS_DIR/dist/cli/index.js" ]]; then
  echo "Building SaviaVaults..."
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  cd "$VAULTS_DIR" && npm run build 2>&1 || echo "Build failed, using existing dist/"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Backup SaviaLabs
echo ""
echo "--- SaviaLabs ---"
if [[ -d "$VAULT_PATH" ]]; then
  node "$VAULTS_DIR/dist/cli/index.js" backup create --path "$VAULT_PATH" 2>&1
else
  echo "SaviaLabs vault not found at $VAULT_PATH"
fi

# Backup Labs (research vault)
echo ""
echo "--- Savia Labs ---"
if [[ -d "$LABS_PATH" ]]; then
  node "$VAULTS_DIR/dist/cli/index.js" backup create --path "$LABS_PATH" 2>&1
else
  echo "Savia Labs vault not found at $LABS_PATH"
fi

# Show backup status
echo ""
echo "--- Backup Status ---"
node "$VAULTS_DIR/dist/cli/index.js" backup list 2>&1

echo ""
echo "=== Backup complete: $(date) ==="
echo "Log: $LOG"
