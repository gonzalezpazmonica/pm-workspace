#!/usr/bin/env bash
# vaults-nextcloud-setup.sh — Configurar credenciales Nextcloud para backups
set -euo pipefail

CONFIG_DIR="$HOME/.savia-vaults"
CONFIG_FILE="$CONFIG_DIR/nextcloud.env"

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

echo "=== SaviaVaults — Nextcloud Backup Setup ==="
echo ""

# Check if already configured
if [[ -f "$CONFIG_FILE" ]]; then
  echo "Nextcloud already configured at $CONFIG_FILE"
  echo "To reconfigure, delete the file and run again."
  cat "$CONFIG_FILE" | sed 's/=.*/=***/'
  exit 0
fi

echo "Choose connection method:"
echo "  1) Local folder (desktop client sync)"
echo "  2) WebDAV direct (no desktop client needed)"
echo ""
read -p "Option [1/2]: " METHOD

case "$METHOD" in
  1)
    read -p "Nextcloud local sync folder path [~/Nextcloud]: " NC_DIR
    NC_DIR="${NC_DIR:-$HOME/Nextcloud}"
    if [[ ! -d "$NC_DIR" ]]; then
      echo "WARNING: $NC_DIR does not exist. Creating..."
      mkdir -p "$NC_DIR"
    fi
    cat > "$CONFIG_FILE" << EOF
# SaviaVaults Nextcloud config — local folder sync
SAVIA_BACKUP_NEXTCLOUD_DIR="$NC_DIR"
EOF
    echo "Configured: local folder sync to $NC_DIR"
    ;;

  2)
    read -p "Nextcloud URL (e.g. https://cloud.example.com): " NC_URL
    read -p "Username: " NC_USER
    read -s -p "Password: " NC_PASS
    echo ""
    cat > "$CONFIG_FILE" << EOF
# SaviaVaults Nextcloud config — WebDAV direct
NEXTCLOUD_URL="$NC_URL"
NEXTCLOUD_USER="$NC_USER"
NEXTCLOUD_PASS="$NC_PASS"
EOF
    echo "Configured: WebDAV to $NC_URL as $NC_USER"
    ;;
  *)
    echo "Invalid option."
    exit 1
    ;;
esac

chmod 600 "$CONFIG_FILE"
echo ""
echo "Configuration saved to $CONFIG_FILE"
echo "To load: source $CONFIG_FILE"
echo "Test with: savia-vaults backup create --path vaults/SaviaLabs"
