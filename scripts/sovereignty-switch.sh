#!/usr/bin/env bash
set -uo pipefail
# sovereignty-switch.sh — Switch between LLM providers for pm-workspace
# Ref: SPEC-066 — Soberanía Tecnológica
# Usage: sovereignty-switch.sh status|local|mistral|claude|test [model]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$HOME/.savia/sovereignty-provider"
PROVIDERS_DIR="$HOME/.savia/providers"

mkdir -p "$PROVIDERS_DIR" "$(dirname "$CONFIG_FILE")"

show_help() {
  cat <<'EOF'
sovereignty-switch.sh — LLM Provider Sovereignty Manager

Commands:
  status          Show active provider and available models
  local [model]   Switch to local Ollama (default: best available)
  mistral         Switch to Mistral AI API (EU-based)
  claude          Switch to Anthropic Claude (default)
  test            Run quick smoke test with active provider
  providers       List configured providers
  help            Show this help

Environment variables set by this script:
  SAVIA_PROVIDER        Active provider name
  SAVIA_MODEL           Active model name
  ANTHROPIC_BASE_URL    (for Claude Code compatibility)
  OPENAI_BASE_URL       (for OpenCode compatibility)
EOF
}

detect_ollama_best() {
  if ! command -v ollama &>/dev/null; then
    echo "none"; return
  fi
  local models
  models=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
  # Prefer by quality: gemma4:e4b > qwen2.5:7b > gemma4:e2b > qwen2.5:3b
  for m in "gemma4:e4b" "qwen2.5:7b" "gemma4:e2b" "qwen2.5:3b"; do
    echo "$models" | grep -q "^${m}$" && echo "$m" && return
  done
  echo "$models" | head -1
}

cmd_status() {
  local provider="claude"
  [[ -f "$CONFIG_FILE" ]] && provider=$(cat "$CONFIG_FILE")

  echo "Sovereignty Status"
  echo "=================="
  echo "  Active provider: $provider"
  echo ""

  echo "  Ollama models:"
  if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null | tail -n +2 | while read -r name rest; do
      echo "    - $name"
    done
    echo "    Best: $(detect_ollama_best)"
  else
    echo "    (not installed)"
  fi
  echo ""

  echo "  OpenCode:"
  if command -v opencode &>/dev/null; then
    echo "    installed ($(opencode --version 2>/dev/null || echo 'unknown'))"
  else
    echo "    (not installed)"
  fi
  echo ""

  echo "  Mistral API:"
  if [[ -f "$PROVIDERS_DIR/mistral-key" ]]; then
    echo "    configured"
  else
    echo "    (not configured — add key to ~/.savia/providers/mistral-key)"
  fi
}

cmd_local() {
  local model="${1:-$(detect_ollama_best)}"
  if [[ "$model" == "none" ]]; then
    echo "ERROR: Ollama not installed or no models available." >&2
    echo "  Install: curl -fsSL https://ollama.com/install.sh | sh" >&2
    echo "  Pull model: ollama pull qwen2.5:7b" >&2
    exit 1
  fi
  echo "local" > "$CONFIG_FILE"
  echo "$model" > "$PROVIDERS_DIR/local-model"

  echo "Switched to LOCAL provider"
  echo "  Model: $model"
  echo "  Ollama: http://localhost:11434"
  echo ""
  echo "  For Claude Code: export ANTHROPIC_BASE_URL=http://localhost:11434/v1"
  echo "  For OpenCode:    opencode --provider ollama --model $model"
}

cmd_mistral() {
  if [[ ! -f "$PROVIDERS_DIR/mistral-key" ]]; then
    echo "ERROR: Mistral API key not configured." >&2
    echo "  1. Get key from https://console.mistral.ai/" >&2
    echo "  2. Save: echo 'your-key' > ~/.savia/providers/mistral-key" >&2
    exit 1
  fi
  echo "mistral" > "$CONFIG_FILE"
  echo "Switched to MISTRAL provider (EU-based)"
  echo "  API: https://api.mistral.ai"
  echo "  Region: EU (France)"
  echo "  GDPR: compliant"
}

cmd_claude() {
  echo "claude" > "$CONFIG_FILE"
  echo "Switched to CLAUDE provider (Anthropic)"
  echo "  API: https://api.anthropic.com"
}

cmd_test() {
  local provider="claude"
  [[ -f "$CONFIG_FILE" ]] && provider=$(cat "$CONFIG_FILE")

  echo "Testing $provider provider..."
  case "$provider" in
    local)
      local model
      model=$(cat "$PROVIDERS_DIR/local-model" 2>/dev/null || detect_ollama_best)
      if ollama run "$model" "Respond with exactly: SOVEREIGNTY_OK" 2>/dev/null | grep -q "SOVEREIGNTY_OK"; then
        echo "PASS: Local model $model responds correctly."
      else
        echo "FAIL: Local model $model did not respond as expected."
        exit 1
      fi
      ;;
    mistral)
      echo "Mistral API test: verify your API access at https://console.mistral.ai/"
      ;;
    claude)
      if curl -s --max-time 5 "${SAVIA_API_UPSTREAM:-https://api.anthropic.com}" >/dev/null 2>&1; then
        echo "PASS: Anthropic API reachable."
      else
        echo "FAIL: Anthropic API unreachable. Consider: sovereignty-switch.sh local"
        exit 1
      fi
      ;;
  esac
}

cmd_providers() {
  echo "Configured providers:"
  echo "  claude   — Anthropic (US) — always available if API reachable"
  [[ -f "$PROVIDERS_DIR/mistral-key" ]] && echo "  mistral  — Mistral AI (EU) — API key configured" || echo "  mistral  — Mistral AI (EU) — NOT configured"
  command -v ollama &>/dev/null && echo "  local    — Ollama ($(detect_ollama_best)) — installed" || echo "  local    — Ollama — NOT installed"
}

case "${1:-help}" in
  status)    cmd_status ;;
  local)     shift; cmd_local "${1:-}" ;;
  mistral)   cmd_mistral ;;
  claude)    cmd_claude ;;
  test)      cmd_test ;;
  providers) cmd_providers ;;
  help|-h|--help) show_help ;;
  *) echo "Unknown: $1" >&2; show_help >&2; exit 1 ;;
esac
