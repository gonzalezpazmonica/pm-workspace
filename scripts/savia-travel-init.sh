#!/bin/bash
# savia-init.sh — Travel Mode Init Script (template)
# Self-contained launcher that runs on any machine to unpack workspace

set -euo pipefail

# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [[ -f /etc/os-release ]]; then
      . /etc/os-release
      echo "$ID"
    else
      echo "linux"
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
    echo "windows"
  else
    echo "unknown"
  fi
}

# Install dependencies
install_deps() {
  local os="$1"
  echo "📦 Installing dependencies for $os..."

  case "$os" in
    ubuntu|debian)
      sudo apt-get update
      sudo apt-get install -y git openssl curl
      ;;
    fedora|rhel|centos)
      sudo yum install -y git openssl curl
      ;;
    arch)
      sudo pacman -S --noconfirm git openssl curl
      ;;
    alpine)
      sudo apk add --no-cache git openssl curl
      ;;
    macos)
      if ! command -v brew &>/dev/null; then
        echo "❌ Homebrew not found. Install from https://brew.sh"
        return 1
      fi
      brew install git openssl
      ;;
    *)
      echo "⚠️  Unknown OS. Install git, openssl manually."
      return 1
      ;;
  esac
  return 0
}

# Main flow
main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🚀 Savia Travel Mode — Init"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local os=$(detect_os)
  echo "🔍 OS detected: $os"

  # Check dependencies
  local missing=0
  for cmd in bash git openssl; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "❌ Missing: $cmd"
      ((missing++)) || true
    else
      echo "✅ $cmd"
    fi
  done

  # Install if needed
  if [[ $missing -gt 0 ]]; then
    read -p "Install missing dependencies? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      install_deps "$os" || {
        echo "❌ Failed to install dependencies"
        return 1
      }
    else
      echo "❌ Cannot proceed without dependencies"
      return 1
    fi
  fi

  # Ask for USB path
  read -p "🔌 USB mount path (e.g., /media/usb0): " usb_path
  [[ ! -d "$usb_path" ]] && {
    echo "❌ Directory not found: $usb_path"
    return 1
  }

  # Ask for passphrase
  read -s -p "🔐 Travel Mode passphrase: " passphrase
  echo

  # Unpack
  echo "📦 Unpacking workspace..."
  local tmp_dir=$(mktemp -d)
  trap "rm -rf $tmp_dir" EXIT

  if ! openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
    -pass "pass:$passphrase" \
    -in "$usb_path/savia-backup.enc" \
    -out "$tmp_dir/savia.tar.gz"; then
    echo "❌ Decryption failed"
    return 1
  fi

  mkdir -p "$HOME/claude"
  tar xzf "$tmp_dir/savia.tar.gz" -C "$HOME/claude" \
    --strip-components=1 2>/dev/null || true

  mkdir -p "$HOME/.claude" "$HOME/.pm-workspace"
  [[ -d "$HOME/claude/.claude" ]] && \
    cp -r "$HOME/claude/.claude"/* "$HOME/.claude/" 2>/dev/null || true

  echo "✅ Workspace ready at $HOME/claude/"
  echo "⏭️  Next: source $HOME/claude/env.sh"
}

main "$@"
