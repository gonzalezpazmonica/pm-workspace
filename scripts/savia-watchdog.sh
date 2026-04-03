#!/usr/bin/env bash
set -uo pipefail
# savia-watchdog.sh — Emergency fallback: detect internet loss, activate local LLM
# Runs as systemd service. Checks connectivity every CHECK_INTERVAL seconds.
# If API unreachable for FAIL_THRESHOLD consecutive checks: activate emergency mode.
# If API returns: deactivate emergency mode and free RAM.

CHECK_INTERVAL="${SAVIA_WATCHDOG_INTERVAL:-300}"
FAIL_THRESHOLD="${SAVIA_WATCHDOG_THRESHOLD:-3}"
API_URL="https://api.anthropic.com"
BACKUP_URL="https://google.com"
STATE_DIR="/tmp/savia-watchdog"
STATE_FILE="$STATE_DIR/state"
LOG_FILE="$STATE_DIR/watchdog.log"
OLLAMA_MODEL="${SAVIA_EMERGENCY_MODEL:-qwen2.5:3b}"
NOTIFY_FILE="$STATE_DIR/last-notify"

mkdir -p "$STATE_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

rotate_log() {
  [[ -f "$LOG_FILE" ]] && [[ $(wc -l < "$LOG_FILE") -gt 500 ]] && tail -250 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
}

check_internet() {
  curl -sf --max-time 5 "$API_URL" >/dev/null 2>&1 && return 0
  curl -sf --max-time 5 "$BACKUP_URL" >/dev/null 2>&1 && return 0
  return 1
}

get_state() { cat "$STATE_FILE" 2>/dev/null || echo "online"; }
set_state() { echo "$1" > "$STATE_FILE"; }

notify_user() {
  local msg="$1"
  # Write to terminal if available
  wall "$msg" 2>/dev/null || true
  # Write notification file for Savia session-init to pick up
  echo "$msg" > "$NOTIFY_FILE"
  log "NOTIFY: $msg"
}

activate_emergency() {
  log "EMERGENCY ACTIVATED — starting Ollama with $OLLAMA_MODEL"
  set_state "emergency"

  # Ensure Ollama is running
  if ! curl -sf --max-time 3 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    systemctl start ollama 2>/dev/null || ollama serve &>/dev/null &
    sleep 3
  fi

  # Warm up model (load into RAM)
  echo "ping" | ollama run "$OLLAMA_MODEL" --nowordwrap >/dev/null 2>&1 || true

  notify_user "SAVIA EMERGENCY: Internet caido. Modelo local $OLLAMA_MODEL activo en localhost:11434. Usa: ollama run $OLLAMA_MODEL"
}

deactivate_emergency() {
  log "INTERNET RESTORED — deactivating emergency mode"
  set_state "online"

  # Unload model to free RAM (stop Ollama if it was started by us)
  ollama stop "$OLLAMA_MODEL" 2>/dev/null || true

  notify_user "SAVIA: Internet restaurado. Modelo local descargado de RAM."
}

# ── Main loop ──

fail_count=0
log "Watchdog started. Interval: ${CHECK_INTERVAL}s, Threshold: $FAIL_THRESHOLD, Model: $OLLAMA_MODEL"

while true; do
  rotate_log

  if check_internet; then
    if [[ $(get_state) == "emergency" ]]; then
      deactivate_emergency
    fi
    fail_count=0
  else
    ((fail_count++)) || true
    log "Check failed ($fail_count/$FAIL_THRESHOLD)"

    if [[ $fail_count -ge $FAIL_THRESHOLD ]] && [[ $(get_state) != "emergency" ]]; then
      activate_emergency
    fi
  fi

  sleep "$CHECK_INTERVAL"
done
