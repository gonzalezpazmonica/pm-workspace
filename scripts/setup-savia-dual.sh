#!/usr/bin/env bash
# setup-savia-dual.sh — Installer for Savia Dual (Linux/macOS)
#
# Fully idempotent: re-running this script will NOT re-download Ollama,
# re-pull models, or overwrite an existing config. Only missing pieces are
# added. Use --force to rewrite config, or --reconfigure to regenerate
# only the config without touching Ollama/models.
#
# Usage:
#   ./scripts/setup-savia-dual.sh              # install + configure (idempotent)
#   ./scripts/setup-savia-dual.sh --dry-run    # show what would happen
#   ./scripts/setup-savia-dual.sh --reconfigure # regenerate config only
#   ./scripts/setup-savia-dual.sh --force      # rewrite config even if present
set -uo pipefail

DRY_RUN=0
RECONFIG_ONLY=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --reconfigure) RECONFIG_ONLY=1; FORCE=1 ;;
    --force) FORCE=1 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -25
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

# ── List installed gemma4 variants (idempotency source of truth) ────────────
list_installed_gemma4() {
  ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -E '^gemma4:' || true
}

# ── Pick gemma4 variant by hardware (ideal pick) ────────────────────────────
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

# ── Reuse already-downloaded variant when possible ──────────────────────────
# Priority:
#   1. If the ideal pick is already installed → use it.
#   2. Else, if ANY gemma4 variant is already installed → reuse it (best fit
#      by hardware, no new download).
#   3. Else → pull the ideal pick.
IDEAL=$(pick_variant "$RAM_GB" "$VRAM_GB")
INSTALLED=$(list_installed_gemma4)

choose_from_installed() {
  # Any already-installed gemma4 variant is acceptable — the user downloaded
  # it deliberately. Prefer the largest one (26b > e4b > e2b) since disk
  # space was already spent.
  local installed="$1"
  local has_e2b=0 has_e4b=0 has_26b=0
  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    case "$m" in
      gemma4:e2b) has_e2b=1 ;;
      gemma4:e4b) has_e4b=1 ;;
      gemma4:26b) has_26b=1 ;;
    esac
  done <<< "$installed"
  [[ $has_26b -eq 1 ]] && { echo "gemma4:26b"; return; }
  [[ $has_e4b -eq 1 ]] && { echo "gemma4:e4b"; return; }
  [[ $has_e2b -eq 1 ]] && { echo "gemma4:e2b"; return; }
  echo ""
}

if echo "$INSTALLED" | grep -qx "$IDEAL"; then
  MODEL="$IDEAL"
  say "Ideal variant already installed: $MODEL (skipping download)"
elif [[ -n "$INSTALLED" ]]; then
  REUSE=$(choose_from_installed "$INSTALLED")
  MODEL="$REUSE"
  say "Reusing already-installed variant: $MODEL (ideal would be $IDEAL, skipping download)"
else
  MODEL="$IDEAL"
  say "No gemma4 variant installed — will pull $MODEL"
fi

# ── Download model (only if truly missing) ──────────────────────────────────
if [[ $RECONFIG_ONLY -eq 0 ]]; then
  if echo "$INSTALLED" | grep -qx "$MODEL"; then
    say "Model $MODEL already present — no download needed."
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

if [[ -f "$CONFIG_PATH" && $FORCE -eq 0 ]]; then
  say "Config already exists: $CONFIG_PATH (use --force to rewrite)"
  WRITE_CONFIG=0
else
  WRITE_CONFIG=1
fi

if [[ -f "$ENV_PATH" && $FORCE -eq 0 ]]; then
  say "Env file already exists: $ENV_PATH (use --force to rewrite)"
  WRITE_ENV=0
else
  WRITE_ENV=1
fi

if [[ $DRY_RUN -eq 0 && $WRITE_CONFIG -eq 1 ]]; then
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
  say "Config written: $CONFIG_PATH"
fi

if [[ $DRY_RUN -eq 0 && $WRITE_ENV -eq 1 ]]; then
  cat > "$ENV_PATH" <<ENV
# Source this file to route Claude Code through Savia Dual.
export ANTHROPIC_BASE_URL="http://127.0.0.1:8787"
export SAVIA_DUAL_ACTIVE="1"
export OLLAMA_KEEP_ALIVE="24h"
ENV
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
