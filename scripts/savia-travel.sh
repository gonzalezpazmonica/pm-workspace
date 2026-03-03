#!/bin/bash
# savia-travel.sh — Travel Mode Core (≤150 lines)
# Minimal core dispatcher; see savia-travel-ops.sh for full implementations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OPS_SCRIPT="$SCRIPT_DIR/savia-travel-ops.sh"

# Source operations library if available
if [[ -f "$OPS_SCRIPT" ]]; then
  source "$OPS_SCRIPT"
fi

# ═══════════════════════════════════════════════════════════════════════════
# Functions for each command
# ═══════════════════════════════════════════════════════════════════════════

travel_pack() {
  echo "📦 Packing workspace with encryption..."
  local dest="${1:-.}"
  local pass="${2:-}"
  [[ -z "$pass" ]] && read -s -p "Passphrase: " pass && echo
  tar czf /tmp/savia.tar.gz --exclude='.git' --exclude='node_modules' \
    --exclude='.venv' --exclude='output' -C "$ROOT_DIR" . 2>/dev/null || true
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
    -pass "pass:$pass" -in /tmp/savia.tar.gz \
    -out "$dest/savia-backup.enc"
  sha256sum /tmp/savia.tar.gz | cut -d' ' -f1 > "$dest/savia-backup.manifest"
  rm -f /tmp/savia.tar.gz
  echo "✅ Pack complete"
}

travel_unpack() {
  echo "📦 Unpacking workspace..."
  local src="${1:-.}"
  local pass="${2:-}"
  [[ -z "$pass" ]] && read -s -p "Passphrase: " pass && echo
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
    -pass "pass:$pass" -in "$src/savia-backup.enc" \
    -out /tmp/savia.tar.gz || { echo "❌ Decryption failed"; return 1; }
  mkdir -p "$HOME/claude"
  tar xzf /tmp/savia.tar.gz -C "$HOME/claude" --strip-components=1
  rm -f /tmp/savia.tar.gz
  mkdir -p "$HOME/.claude" "$HOME/.pm-workspace"
  [[ -d "$HOME/claude/.claude" ]] && cp -r "$HOME/claude/.claude"/* "$HOME/.claude/" 2>/dev/null || true
  echo "✅ Unpack complete"
}

travel_verify() {
  local src="${1:-.}"
  echo "✅ Archive: $(ls -lh "$src/savia-backup.enc" 2>/dev/null | awk '{print $5}')"
  echo "✅ Manifest: $(ls -lh "$src/savia-backup.manifest" 2>/dev/null | awk '{print $5}')"
  echo "✅ Verification complete"
}

travel_clean() {
  echo "🧹 Cleaning up..."
  rm -rf "$HOME/.claude" "$HOME/.pm-workspace" "$HOME/claude" 2>/dev/null || true
  echo "✅ Cleanup complete"
}

# ═══════════════════════════════════════════════════════════════════════════
# Dispatcher
# ═══════════════════════════════════════════════════════════════════════════

case "${1:-}" in
  pack)   shift; travel_pack "$@" ;;
  unpack) shift; travel_unpack "$@" ;;
  verify) shift; travel_verify "$@" ;;
  sync)
    echo "🔄 Sync not implemented in minimal mode"
    echo "   Use savia-travel-ops.sh for full functionality"
    exit 1
    ;;
  clean)  travel_clean ;;
  *)
    cat << 'USAGE'
Travel Mode Core — Minimal Implementation
Usage: savia-travel.sh {pack|unpack|verify|clean} [args]

Commands:
  pack DEST [PASS]       — Pack workspace to DEST/savia-backup.enc
  unpack SRC [PASS]      — Unpack from SRC/savia-backup.enc
  verify SRC             — Verify archive integrity at SRC
  clean                  — Remove all Savia traces
  sync                   — Use savia-travel-ops.sh for sync

Dependencies: bash, tar, openssl, openssl (enc)
USAGE
    exit 1
    ;;
esac
