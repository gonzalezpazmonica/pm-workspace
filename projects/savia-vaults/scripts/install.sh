#!/usr/bin/env bash
# install.sh — SaviaVaults installer (Linux / macOS)
# Copyright (c) 2026 Savia. MIT License.
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[savia-vaults]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

info "SaviaVaults Installer"
echo ""

# ── Check Node.js ──
if ! command -v node &>/dev/null; then
  err "Node.js not found. Install Node.js 22+ from https://nodejs.org"
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [[ "$NODE_VERSION" -lt 22 ]]; then
  err "Node.js $NODE_VERSION detected. SaviaVaults requires Node.js 22+. Install from https://nodejs.org"
fi
info "Node.js $(node -v) ✓"

# ── Check Git ──
if ! command -v git &>/dev/null; then
  err "Git not found. Install git from https://git-scm.com"
fi
info "Git $(git --version | cut -d' ' -f3) ✓"

# ── Check npm ──
if ! command -v npm &>/dev/null; then
  err "npm not found. Reinstall Node.js (npm comes bundled)."
fi
info "npm $(npm -v) ✓"
echo ""

# ── Install globally ──
info "Installing savia-vaults..."
npm install -g savia-vaults 2>&1 || {
  warn "Global install failed. Trying npx fallback..."
  info "Use: npx savia-vaults <command>"
  exit 0
}

info "SaviaVaults installed successfully!"
echo ""
info "Quick start:"
echo "  savia-vaults init my-knowledge"
echo "  cd vaults/my-knowledge"
echo "  savia-vaults serve --transport mcp"
echo ""
info "Documentation: https://github.com/gonzalezpazmonica/savia-vaults"
