#!/usr/bin/env bash
# model-capability-resolver.sh — Resolve model capabilities from YAML registry
# Outputs SAVIA_* env vars for the given model. Falls back to default.
# Usage: source <(./scripts/model-capability-resolver.sh [--model name])
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

# Read stdin for hook compatibility
cat /dev/stdin > /dev/null 2>&1 || true

# ── Determine model (provider-agnostic) ────────────────────────────────────
MODEL="${SAVIA_MODEL:-${CLAUDE_MODEL_AGENT:-}}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    *) shift ;;
  esac
done
MODEL="${MODEL:-default}"

# ── Locate config file ──────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/model-capabilities.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  # Fallback defaults if config missing
  echo "export SAVIA_CONTEXT_WINDOW=200000"
  echo "export SAVIA_MODEL_TIER=fast"
  echo "export SAVIA_COMPACT_THRESHOLD=50"
  echo "export SAVIA_SUPPORTS_THINKING=false"
  echo "export SAVIA_DETECTED_MODEL=default"
  exit 0
fi

# ── Parse YAML with grep/sed (no yq dependency) ─────────────────────────────
# Extract block for the target model, or fall back to default
extract_field() {
  local model="$1" field="$2" fallback="$3"
  local value=""
  # Try model-specific block first
  if [ "$model" != "default" ]; then
    value=$(sed -n "/^  ${model}:/,/^  [a-z]/p" "$CONFIG_FILE" \
      | grep "    ${field}:" | head -1 \
      | sed 's/.*: *//' | tr -d '[:space:]')
  fi
  # Fall back to default block
  if [ -z "$value" ]; then
    value=$(sed -n '/^default:/,/^[a-z]/p' "$CONFIG_FILE" \
      | grep "  ${field}:" | head -1 \
      | sed 's/.*: *//' | tr -d '[:space:]')
  fi
  echo "${value:-$fallback}"
}

CONTEXT_WINDOW=$(extract_field "$MODEL" "context_window" "200000")
TIER=$(extract_field "$MODEL" "tier" "fast")
COMPACT_PCT=$(extract_field "$MODEL" "recommended_compact_threshold_pct" "50")
THINKING=$(extract_field "$MODEL" "supports_extended_thinking" "false")

# ── Output env vars ──────────────────────────────────────────────────────────
echo "export SAVIA_CONTEXT_WINDOW=${CONTEXT_WINDOW}"
echo "export SAVIA_MODEL_TIER=${TIER}"
echo "export SAVIA_COMPACT_THRESHOLD=${COMPACT_PCT}"
echo "export SAVIA_SUPPORTS_THINKING=${THINKING}"
echo "export SAVIA_DETECTED_MODEL=${MODEL}"
