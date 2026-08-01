#!/usr/bin/env bash
# vaults-backup-cron-install.sh — Install cron job for SaviaVaults backups
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/vaults-backup-cron.sh"
CRON_SCHEDULE="${1:-0 3 * * *}"  # Default: daily at 3 AM
CRON_ENTRY="$CRON_SCHEDULE bash $SCRIPT"

echo "=== SaviaVaults Backup Cron Installer ==="
echo ""
echo "Schedule: $CRON_SCHEDULE (default: daily at 3 AM)"
echo "Script:   $SCRIPT"
echo ""

# Verify script exists and is executable
if [[ ! -x "$SCRIPT" ]]; then
  echo "ERROR: $SCRIPT not found or not executable"
  exit 1
fi

# Check Nextcloud config
if [[ ! -f "$HOME/.savia-vaults/nextcloud.env" ]]; then
  echo "Nextcloud not configured."
  echo "Run first: bash scripts/vaults-nextcloud-setup.sh"
  echo ""
  read -p "Continue without Nextcloud? [y/N]: " CONT
  [[ "$CONT" != "y" && "$CONT" != "Y" ]] && exit 0
fi

# Install cron job
CURRENT=$(crontab -l 2>/dev/null || true)

if echo "$CURRENT" | grep -qF "$SCRIPT"; then
  echo "Cron job already installed."
  echo "Current entry:"
  echo "$CURRENT" | grep "$SCRIPT"
  echo ""
  read -p "Update schedule? [y/N]: " UPDATE
  if [[ "$UPDATE" == "y" || "$UPDATE" == "Y" ]]; then
    NEW_CRON=$(echo "$CURRENT" | grep -v "$SCRIPT")
    NEW_CRON="$NEW_CRON
$CRON_ENTRY"
    echo "$NEW_CRON" | crontab -
    echo "Updated to: $CRON_ENTRY"
  fi
else
  NEW_CRON="$CURRENT
$CRON_ENTRY"
  echo "$NEW_CRON" | crontab -
  echo "Cron job installed: $CRON_ENTRY"
fi

echo ""
echo "=== Cron Installation Complete ==="
echo "Schedule: $CRON_SCHEDULE"
echo "Logs:     $HOME/.savia-vaults/logs/"
echo ""
echo "Test backup now: bash $SCRIPT"
echo "Remove cron:     crontab -e  (delete the line with vaults-backup-cron)"
