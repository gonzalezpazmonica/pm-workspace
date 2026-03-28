#!/bin/bash
# token-tracker-middleware.sh — Monitor y respuesta automática a uso de tokens
# Tier: standard | Async: true | Event: PostToolUse
set -euo pipefail

# Profile gate — solo en perfiles standard/strict
LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
[[ -f "$LIB_DIR/profile-gate.sh" ]] && source "$LIB_DIR/profile-gate.sh" && profile_gate "standard"

USED="${CLAUDE_CONTEXT_TOKENS_USED:-0}"
MAX="${CLAUDE_CONTEXT_TOKENS_MAX:-200000}"

[[ "$USED" -eq 0 ]] && exit 0  # Variables no disponibles → fail-safe

PCT=$(( USED * 100 / MAX ))

LOG_FILE="${CLAUDE_PROJECT_DIR:-$(pwd)}/output/context-token-log.jsonl"

log_event() {
  local zone="$1" msg="$2"
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "{\"ts\":\"$ts\",\"zone\":\"$zone\",\"pct\":$PCT,\"used\":$USED,\"max\":$MAX}" >> "$LOG_FILE" 2>/dev/null || true
}

if [[ $PCT -ge 85 ]]; then
  log_event "critical" "Auto-compact triggered"
  echo "⚡ Contexto crítico (${PCT}%) — compactando automáticamente..." >&2
  SCRIPTS_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/scripts"
  [[ -x "$SCRIPTS_DIR/auto-compact.sh" ]] && bash "$SCRIPTS_DIR/auto-compact.sh" &
elif [[ $PCT -ge 70 ]]; then
  log_event "alert" "Heavy ops blocked"
  echo "⚠️  Contexto alto (${PCT}%) — ejecuta /compact antes de operaciones pesadas" >&2
elif [[ $PCT -ge 50 ]]; then
  echo "💡 Contexto al ${PCT}% — /compact recomendado" >&2
fi

exit 0
