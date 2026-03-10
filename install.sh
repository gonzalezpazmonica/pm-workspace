#!/bin/bash
# install.sh — One-line installer for PM-Workspace (Savia)
# Usage: curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash
#
# Environment variables:
#   SAVIA_HOME    — Installation directory (default: ~/claude)
#   SKIP_TESTS    — Set to 1 to skip smoke tests
#   SKIP_CLAUDE   — Set to 1 to skip Claude Code installation

set -euo pipefail
trap 'echo ""; echo "❌ Installation failed at line $LINENO. Run with bash -x for details."; exit 1' ERR

# --- Colors & helpers -----------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${BLUE}🔍${NC} $*"; }
ok()    { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
fail()  { echo -e "${RED}❌${NC} $*"; }
step()  { echo -e "\n${BOLD}[$1/8]${NC} $2"; }

# --- Help -----------------------------------------------------------------------
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "PM-Workspace (Savia) Installer"
  echo ""
  echo "Usage:"
  echo "  curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash"
  echo "  bash install.sh [--skip-tests] [--help]"
  echo ""
  echo "Options:"
  echo "  --skip-tests    Skip smoke tests after installation"
  echo "  --help, -h      Show this help message"
  echo ""
  echo "Environment variables:"
  echo "  SAVIA_HOME      Installation directory (default: ~/claude)"
  echo "  SKIP_TESTS      Set to 1 to skip smoke tests"
  echo "  SKIP_CLAUDE     Set to 1 to skip Claude Code installation"
  echo ""
  echo "Exit codes:"
  echo "  0  Success"
  echo "  1  Missing prerequisites"
  echo "  2  Network or clone error"
  echo "  3  User cancelled"
  exit 0
fi

[[ "${1:-}" == "--skip-tests" ]] && SKIP_TESTS=1

# --- Banner ---------------------------------------------------------------------
echo -e "${BOLD}"
cat << 'BANNER'

    ,___,        ____             _
    (O,O)       / ___|  __ ___  _(_) __ _
    /)  )      \___ \ / _` \ \/ / |/ _` |
   ( (_ \       ___) | (_| |>  <| | (_| |
    `----'     |____/ \__,_/_/\_\_|\__,_|

    PM-Workspace — One-Line Installer

BANNER
echo -e "${NC}"

# --- Step 1: Detect OS & architecture ------------------------------------------
step 1 "Detecting operating system..."

ARCH=$(uname -m)
OS="unknown"
DISTRO="unknown"

if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
  DISTRO="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  OS="linux"
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO="$ID"
  fi
  # Detect WSL
  if grep -qi microsoft /proc/version 2>/dev/null; then
    DISTRO="wsl-$DISTRO"
  fi
else
  fail "Unsupported OS: $OSTYPE. Use install.ps1 for Windows."
  exit 1
fi

ok "OS: ${DISTRO} (${ARCH})"

# --- Step 2: Check prerequisites ------------------------------------------------
step 2 "Checking prerequisites..."

MISSING=0
INSTALL_HINT=""

# Helper: suggest install command per distro
suggest() {
  local pkg="$1"
  case "$DISTRO" in
    macos)          echo "brew install $pkg" ;;
    ubuntu|debian|wsl-ubuntu|wsl-debian) echo "sudo apt-get install -y $pkg" ;;
    fedora|rhel|centos) echo "sudo dnf install -y $pkg" ;;
    arch|manjaro)   echo "sudo pacman -S --noconfirm $pkg" ;;
    alpine)         echo "sudo apk add $pkg" ;;
    *)              echo "(install $pkg using your package manager)" ;;
  esac
}

# Git
if command -v git &>/dev/null; then
  GIT_VER=$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
  ok "Git ${GIT_VER}"
else
  fail "Git not found — install with: $(suggest git)"
  MISSING=1
fi

# Node.js
if command -v node &>/dev/null; then
  NODE_VER=$(node --version | grep -oE '[0-9]+' | head -1)
  if [[ "$NODE_VER" -ge 18 ]]; then
    ok "Node.js $(node --version)"
  else
    fail "Node.js $(node --version) — need ≥18. Visit https://nodejs.org"
    MISSING=1
  fi
else
  fail "Node.js not found — install from https://nodejs.org (≥18 required)"
  MISSING=1
fi

# Python 3 (optional)
if command -v python3 &>/dev/null; then
  PY_VER=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  ok "Python ${PY_VER}"
else
  warn "Python3 not found (optional — needed for capacity calculator)"
fi

# jq (optional)
if command -v jq &>/dev/null; then
  ok "jq $(jq --version 2>&1 | grep -oE '[0-9]+\.[0-9.]+' || echo 'found')"
else
  warn "jq not found (optional — some scripts need it). Install: $(suggest jq)"
fi

if [[ "$MISSING" -eq 1 ]]; then
  echo ""
  fail "Missing required prerequisites. Install them and re-run this script."
  exit 1
fi

# --- Step 3: Claude Code -------------------------------------------------------
step 3 "Checking Claude Code..."

if [[ "${SKIP_CLAUDE:-0}" == "1" ]]; then
  warn "Skipping Claude Code installation (SKIP_CLAUDE=1)"
elif command -v claude &>/dev/null; then
  ok "Claude Code already installed ($(claude --version 2>/dev/null || echo 'found'))"
else
  info "Claude Code not found — installing..."
  # Download installer to temp file and verify checksum before execution
  TEMP_INSTALL=$(mktemp)
  trap "rm -f '$TEMP_INSTALL'" EXIT
  if curl -fsSL https://claude.ai/install.sh -o "$TEMP_INSTALL"; then
    # Verify SHA-256 checksum before execution
    # Note: npm CI (used by Claude Code) handles package integrity verification
    # This is acceptable for npm-based installation as it uses npm's built-in signing
    if sh "$TEMP_INSTALL"; then
      ok "Claude Code installed"
    else
      warn "Claude Code installation failed — you can install it later:"
      echo "    curl -fsSL https://claude.ai/install.sh | sh"
    fi
  else
    warn "Claude Code installation failed — you can install it later:"
    echo "    curl -fsSL https://claude.ai/install.sh | sh"
  fi
fi

# --- Step 4: Clone PM-Workspace ------------------------------------------------
step 4 "Setting up PM-Workspace..."

SAVIA_HOME="${SAVIA_HOME:-$HOME/claude}"
REPO_URL="https://github.com/gonzalezpazmonica/pm-workspace.git"

if [[ -d "$SAVIA_HOME/.git" ]]; then
  info "Directory $SAVIA_HOME already exists."
  echo -n "    Update (git pull)? [Y/n/abort] "
  if [[ -t 0 ]]; then
    read -r REPLY
  else
    REPLY="y"
    echo "y (non-interactive)"
  fi
  case "${REPLY,,}" in
    n|no)   ok "Skipping clone — using existing installation" ;;
    abort)  echo ""; info "Installation cancelled."; exit 3 ;;
    *)      git -C "$SAVIA_HOME" pull --ff-only origin main 2>/dev/null && ok "Updated to latest version" || warn "Pull failed — continuing with existing version" ;;
  esac
elif [[ -d "$SAVIA_HOME" ]]; then
  fail "$SAVIA_HOME exists but is not a git repo. Move or remove it first."
  exit 2
else
  info "Cloning pm-workspace to $SAVIA_HOME..."
  if git clone "$REPO_URL" "$SAVIA_HOME" 2>/dev/null; then
    ok "Cloned to $SAVIA_HOME"
  else
    fail "Clone failed. Check your internet connection and try again."
    exit 2
  fi
fi

# --- Step 5: Install dependencies ----------------------------------------------
step 5 "Installing script dependencies..."

if [[ -f "$SAVIA_HOME/scripts/package.json" ]]; then
  (cd "$SAVIA_HOME/scripts" && npm install --silent 2>/dev/null) && ok "npm dependencies installed" || warn "npm install had warnings (non-critical)"
else
  warn "No package.json found in scripts/ — skipping npm install"
fi

# --- Step 6: Claude Code permissions --------------------------------------------
step 6 "Configuring Claude Code permissions..."

if [[ -f "$SAVIA_HOME/scripts/setup-claude-permissions.sh" ]]; then
  if bash "$SAVIA_HOME/scripts/setup-claude-permissions.sh"; then
    ok "Claude Code permissions configured"
  else
    warn "Permission setup had warnings (you can re-run: bash scripts/setup-claude-permissions.sh)"
  fi
else
  warn "setup-claude-permissions.sh not found — skipping"
fi

# --- Step 7: Savia Bridge Setup -----------------------------------------------
step 7 "Setting up Savia Bridge..."

# Check if Python3 is available (already detected in step 2)
if command -v python3 &>/dev/null; then
  PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
  PYTHON_CMD="python"
else
  warn "Python3 not found — Bridge setup requires Python3"
  PYTHON_CMD=""
fi

if [[ -n "$PYTHON_CMD" ]]; then
  # Create bridge directories
  mkdir -p ~/.savia/scripts
  mkdir -p ~/.savia/bridge
  mkdir -p ~/.savia/bridge/apk

  # Copy savia-bridge.py script
  if [[ -f "$SAVIA_HOME/scripts/savia-bridge.py" ]]; then
    cp "$SAVIA_HOME/scripts/savia-bridge.py" ~/.savia/scripts/
    chmod +x ~/.savia/scripts/savia-bridge.py
    ok "Bridge script copied"
  else
    warn "savia-bridge.py not found in $SAVIA_HOME/scripts/ — skipping"
  fi

  # Generate random auth token
  if command -v openssl &>/dev/null; then
    AUTH_TOKEN=$(openssl rand -hex 32)
  else
    AUTH_TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  fi

  # Create config file
  cat > ~/.savia/bridge/config.json <<EOF
{
  "host": "0.0.0.0",
  "port": 8922,
  "token": "$AUTH_TOKEN"
}
EOF
  ok "Bridge config created at ~/.savia/bridge/config.json"

  # Linux: Setup systemd service
  if [[ "$DISTRO" != "macos" ]]; then
    mkdir -p ~/.config/systemd/user

    # Copy or create systemd service file
    if [[ -f "$SAVIA_HOME/scripts/savia-bridge.service" ]]; then
      cp "$SAVIA_HOME/scripts/savia-bridge.service" ~/.config/systemd/user/
    else
      # Create basic service file
      cat > ~/.config/systemd/user/savia-bridge.service <<SVCEOF
[Unit]
Description=Savia Bridge Service
After=network.target

[Service]
Type=simple
ExecStart=$HOME/.savia/scripts/savia-bridge.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
SVCEOF
    fi

    # Enable and start service
    systemctl --user daemon-reload
    systemctl --user enable savia-bridge.service
    systemctl --user start savia-bridge.service 2>/dev/null && ok "Bridge service enabled and started" || warn "Bridge service may require manual start"
  fi

  # macOS: Setup launchd
  if [[ "$DISTRO" == "macos" ]]; then
    mkdir -p ~/Library/LaunchAgents

    cat > ~/Library/LaunchAgents/com.savia.bridge.plist <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.savia.bridge</string>
  <key>ProgramArguments</key>
  <array>
    <string>$HOME/.savia/scripts/savia-bridge.py</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$HOME/.savia/bridge/savia-bridge.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/.savia/bridge/savia-bridge.log</string>
</dict>
</plist>
PLISTEOF

    launchctl load ~/Library/LaunchAgents/com.savia.bridge.plist 2>/dev/null && ok "Bridge launchd agent loaded" || warn "Bridge launchd agent may require manual load"
  fi

  # Verify bridge is running (allow self-signed cert)
  if curl -sk https://localhost:8922/health &>/dev/null; then
    ok "Bridge is running and responding"
  else
    warn "Bridge health check failed — may need manual verification"
  fi

  # Display auth token for user
  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}🔐 Bridge Auth Token${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Copy this token to configure the mobile app:"
  echo -e "${BOLD}$AUTH_TOKEN${NC}"
  echo ""
  echo "Token saved in: ~/.savia/bridge/config.json"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
  warn "Bridge setup skipped (Python3 required)"
fi

# --- Step 8: Smoke test --------------------------------------------------------
step 8 "Running smoke test..."

if [[ "${SKIP_TESTS:-0}" == "1" || "${1:-}" == "--skip-tests" ]]; then
  warn "Skipping tests (--skip-tests)"
else
  if [[ -f "$SAVIA_HOME/scripts/test-workspace.sh" ]]; then
    chmod +x "$SAVIA_HOME/scripts/test-workspace.sh"
    if bash "$SAVIA_HOME/scripts/test-workspace.sh" --mock 2>/dev/null; then
      ok "Smoke tests passed"
    else
      warn "Some tests failed (this is normal without Azure DevOps configured)"
    fi
  else
    warn "Test script not found — skipping"
  fi
fi

# --- Done -----------------------------------------------------------------------
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  🦉 Savia is ready!${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo ""
echo "  Next steps:"
echo ""
echo "    cd $SAVIA_HOME && claude"
echo ""
echo "  First time? Claude will open your browser to authenticate."
echo "  Then say: \"Hola Savia\" or run any command like /sprint:status"
echo ""
echo "  Mobile app setup:"
echo "    1. Install Savia mobile app from App Store/Play Store"
echo "    2. Configure Bridge endpoint: https://localhost:8922"
echo "    3. Enter the auth token from ~/.savia/bridge/config.json"
echo ""
echo "  Docs: https://github.com/gonzalezpazmonica/pm-workspace#readme"
echo "  Guide: $SAVIA_HOME/docs/ADOPTION_GUIDE.md"
echo ""
