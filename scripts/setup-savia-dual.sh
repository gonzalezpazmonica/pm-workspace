#!/usr/bin/env bash
# setup-savia-dual.sh — Installer for Savia Dual (Linux/macOS)
#
# Installs/updates Ollama, detects hardware, picks the best gemma4 variant,
# downloads it, writes config, and prepares the environment to run the
# savia-dual-proxy. Does NOT log hardware specifics to any tracked file.
#
# Usage:
#   ./scripts/setup-savia-dual.sh              # install + configure
#   ./scripts/setup-savia-dual.sh --dry-run    # show what would happen
#   ./scripts/setup-savia-dual.sh --reconfigure # regenerate config only
set -uo pipefail

DRY_RUN=0
RECONFIG_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --reconfigure) RECONFIG_ONLY=1 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -20
      exit 0
      ;;
  esac
done

say() { printf '\033[0;36m[savia-dual]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[savia-dual]\033[0m %s\n' "$*" >&2; }
err() { printf '\033[0;31m[savia-dual]\033[0m %s\n' "$*" >&2; }
run() { if [[ $DRY_RUN -eq 1 ]]; then echo "  + $*"; else eval "$*"; fi }

# ── Detect OS ───────────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
  Linux) PLATFORM="linux" ;;
  Darwin) PLATFORM="macos" ;;
  *) err "Unsupported OS: $OS (use savia-dual-setup.ps1 on Windows)"; exit 1 ;;
esac
say "Platform: $PLATFORM"

# ── Install/update Ollama ───────────────────────────────────────────────────
install_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    say "Ollama present: $(ollama --version 2>/dev/null | head -1)"
    return 0
  fi
  say "Installing Ollama from official installer..."
  if [[ "$PLATFORM" == "linux" ]]; then
    run "curl -fsSL https://ollama.com/install.sh | sh"
  else
    if command -v brew >/dev/null 2>&1; then
      run "brew install ollama"
    else
      warn "Homebrew not found. Download Ollama from https://ollama.com/download/mac"
      return 1
    fi
  fi
}

if [[ $RECONFIG_ONLY -eq 0 ]]; then
  install_ollama || exit 1
fi

# ── Start Ollama daemon (idempotent) ────────────────────────────────────────
ensure_ollama_running() {
  if curl -fsS --max-time 3 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    return 0
  fi
  say "Starting Ollama daemon..."
  if [[ "$PLATFORM" == "linux" ]]; then
    if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q "^ollama.service"; then
      run "sudo systemctl start ollama" || run "nohup ollama serve >/tmp/ollama.log 2>&1 &"
    else
      run "nohup ollama serve >/tmp/ollama.log 2>&1 &"
    fi
  else
    run "nohup ollama serve >/tmp/ollama.log 2>&1 &"
  fi
  sleep 2
}
[[ $RECONFIG_ONLY -eq 0 ]] && ensure_ollama_running

# ── Detect hardware (stays local, never logged to tracked files) ────────────
detect_ram_gb() {
  if [[ "$PLATFORM" == "linux" ]]; then
    awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo
  else
    sysctl -n hw.memsize | awk '{printf "%d", $1/1024/1024/1024}'
  fi
}

detect_vram_gb() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null \
      | head -1 | awk '{printf "%d", $1/1024}'
    return
  fi
  if [[ "$PLATFORM" == "macos" ]]; then
    # Apple Silicon: unified memory, approximate as RAM/2
    local ram; ram=$(detect_ram_gb)
    echo "$((ram / 2))"
    return
  fi
  echo "0"
}

RAM_GB=$(detect_ram_gb)
VRAM_GB=$(detect_vram_gb)
say "Hardware detection complete (values kept local, not logged)."

# ── Pick gemma4 variant ─────────────────────────────────────────────────────
# Rationale kept generic so no hardware specifics leak to docs.
pick_variant() {
  local ram="$1" vram="$2"
  if [[ "$ram" -lt 12 ]]; then
    echo "gemma4:e2b"; return
  fi
  if [[ "$ram" -lt 24 ]]; then
    echo "gemma4:e4b"; return
  fi
  if [[ "$vram" -ge 12 ]]; then
    echo "gemma4:26b"; return
  fi
  if [[ "$ram" -ge 32 ]]; then
    echo "gemma4:e4b"; return
  fi
  echo "gemma4:e2b"
}

MODEL=$(pick_variant "$RAM_GB" "$VRAM_GB")
say "Selected local model: $MODEL"

# ── Download model ──────────────────────────────────────────────────────────
if [[ $RECONFIG_ONLY -eq 0 ]]; then
  if ollama list 2>/dev/null | awk '{print $1}' | grep -qx "$MODEL"; then
    say "Model $MODEL already present."
  else
    say "Downloading $MODEL (this may take a while)..."
    run "ollama pull $MODEL"
  fi
fi

# ── Write config ────────────────────────────────────────────────────────────
CONFIG_DIR="$HOME/.savia/dual"
CONFIG_PATH="$CONFIG_DIR/config.json"
ENV_PATH="$CONFIG_DIR/env"
run "mkdir -p '$CONFIG_DIR'"

if [[ $DRY_RUN -eq 0 ]]; then
  cat > "$CONFIG_PATH" <<JSON
{
  "listen_host": "127.0.0.1",
  "listen_port": 8787,
  "anthropic_upstream": "https://api.anthropic.com",
  "ollama_upstream": "http://127.0.0.1:11434",
  "fallback_triggers": {
    "network_error": true,
    "http_5xx": true,
    "http_429": true,
    "timeout_seconds": 30
  },
  "circuit_breaker": {
    "consecutive_failures": 3,
    "cooldown_seconds": 60
  },
  "local_model": "$MODEL",
  "log_path": "$HOME/.savia/dual/events.jsonl"
}
JSON
  cat > "$ENV_PATH" <<ENV
# Source this file to route Claude Code through Savia Dual.
export ANTHROPIC_BASE_URL="http://127.0.0.1:8787"
export SAVIA_DUAL_ACTIVE="1"
export OLLAMA_KEEP_ALIVE="24h"
ENV
  say "Config written: $CONFIG_PATH"
  say "Env file:       $ENV_PATH"
fi

# ── Final instructions ──────────────────────────────────────────────────────
cat <<EOF

Savia Dual is ready.

Next steps:
  1. Start the proxy in a terminal:
       python3 $(pwd)/scripts/savia-dual-proxy.py

  2. In another terminal, source the env file and start Claude Code:
       source $ENV_PATH
       claude

  3. Verify routing:
       curl -s http://127.0.0.1:8787/health
       tail -f $HOME/.savia/dual/events.jsonl

To reconfigure later: ./scripts/setup-savia-dual.sh --reconfigure
EOF
