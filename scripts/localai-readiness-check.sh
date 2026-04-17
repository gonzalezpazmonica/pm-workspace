#!/usr/bin/env bash
# localai-readiness-check.sh — SPEC-122
# Verifica que LocalAI (https://github.com/mudler/LocalAI) está listo para
# servir como fallback Anthropic API shim cuando la cloud API cae.
#
# Usage:
#   bash scripts/localai-readiness-check.sh [--url URL] [--model MODEL] [--json]
#
# Env:
#   LOCALAI_URL     default http://localhost:8080
#   LOCALAI_MODEL   default claude-compatible-local (checked for presence)
#
# Exit codes:
#   0 = READY (all checks OK)
#   1 = WARNING (non-blocking issues)
#   2 = FAIL (cannot operate — LocalAI down / no model / version too old)

set -uo pipefail

LOCALAI_URL="${LOCALAI_URL:-http://localhost:8080}"
LOCALAI_MODEL="${LOCALAI_MODEL:-claude-compatible-local}"
OUTPUT_JSON=false
MIN_VERSION="3.10.0"  # Anthropic API compat desde v3.10.0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) LOCALAI_URL="$2"; shift 2 ;;
    --model) LOCALAI_MODEL="$2"; shift 2 ;;
    --json) OUTPUT_JSON=true; shift ;;
    --help|-h)
      sed -n '2,15p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *)
      echo "Error: unknown option $1" >&2
      exit 2 ;;
  esac
done

# ── state ─────────────────────────────────────────────────────────────────
declare -a CHECKS=()
OVERALL=0   # 0=OK 1=WARN 2=FAIL

record() {
  local status="$1" check="$2" msg="$3"
  CHECKS+=("$status|$check|$msg")
  case "$status" in
    WARN) (( OVERALL < 1 )) && OVERALL=1 ;;
    FAIL) OVERALL=2 ;;
  esac
}

# ── checks ────────────────────────────────────────────────────────────────

check_localai_running() {
  if curl -fsS --max-time 3 "$LOCALAI_URL/readyz" >/dev/null 2>&1; then
    record "OK" "localai_running" "LocalAI responding on $LOCALAI_URL"
    return 0
  fi
  if curl -fsS --max-time 3 "$LOCALAI_URL/v1/models" >/dev/null 2>&1; then
    record "OK" "localai_running" "LocalAI v1/models responding on $LOCALAI_URL"
    return 0
  fi
  record "FAIL" "localai_running" "LocalAI NOT responding on $LOCALAI_URL"
  return 1
}

check_anthropic_compat() {
  # v3.10.0+ exposes /v1/messages Anthropic-compatible
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 \
    -X OPTIONS "$LOCALAI_URL/v1/messages" 2>/dev/null || echo "000")
  # 200, 204, 405 (Method Not Allowed but endpoint exists) all indicate presence
  if [[ "$http_code" =~ ^(200|204|405)$ ]]; then
    record "OK" "anthropic_compat" "Endpoint /v1/messages available (Anthropic shim)"
    return 0
  fi
  record "FAIL" "anthropic_compat" "No Anthropic-compat endpoint (needs LocalAI >= $MIN_VERSION)"
  return 1
}

check_model_available() {
  local models_json
  models_json=$(curl -fsS --max-time 5 "$LOCALAI_URL/v1/models" 2>/dev/null || echo "{}")
  if echo "$models_json" | grep -q "\"$LOCALAI_MODEL\""; then
    record "OK" "model_available" "Model '$LOCALAI_MODEL' loaded"
    return 0
  fi
  # Check ANY model loaded
  if echo "$models_json" | grep -qE '"id"\s*:'; then
    record "WARN" "model_available" "Model '$LOCALAI_MODEL' NOT loaded (but other models available)"
    return 1
  fi
  record "FAIL" "model_available" "NO models loaded in LocalAI"
  return 1
}

check_ram() {
  local ram_kb; ram_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo "0")
  local ram_gb=$(( ram_kb / 1024 / 1024 ))
  if (( ram_gb >= 16 )); then
    record "OK" "ram" "RAM ${ram_gb}GB (sufficient for 4-bit 7-13B models)"
  elif (( ram_gb >= 8 )); then
    record "WARN" "ram" "RAM ${ram_gb}GB (limited — use 4-bit small models only)"
  else
    record "FAIL" "ram" "RAM ${ram_gb}GB insufficient (<8GB)"
  fi
}

check_disk() {
  local free_gb
  free_gb=$(df -BG --output=avail "$HOME" 2>/dev/null | tail -1 | tr -d 'G ' || echo "0")
  free_gb="${free_gb:-0}"
  if (( free_gb >= 20 )); then
    record "OK" "disk" "Disk free ${free_gb}GB"
  elif (( free_gb >= 5 )); then
    record "WARN" "disk" "Disk free ${free_gb}GB (limited for model downloads)"
  else
    record "FAIL" "disk" "Disk free ${free_gb}GB insufficient"
  fi
}

# ── run ───────────────────────────────────────────────────────────────────

check_localai_running || true
check_anthropic_compat || true
check_model_available || true
check_ram
check_disk

# ── output ────────────────────────────────────────────────────────────────

if $OUTPUT_JSON; then
  printf '{"overall":%d,"checks":[' "$OVERALL"
  FIRST=true
  for c in "${CHECKS[@]}"; do
    IFS='|' read -r status check msg <<< "$c"
    $FIRST && FIRST=false || printf ','
    printf '{"status":"%s","check":"%s","message":"%s"}' \
      "$status" "$check" "$msg"
  done
  printf ']}\n'
else
  echo "=== LocalAI Readiness Check ==="
  for c in "${CHECKS[@]}"; do
    IFS='|' read -r status check msg <<< "$c"
    printf '[%-4s] %s: %s\n' "$status" "$check" "$msg"
  done
  echo ""
  case "$OVERALL" in
    0) echo "Estado: READY" ;;
    1) echo "Estado: READY (con warnings — ver arriba)" ;;
    2) echo "Estado: NOT READY — revisa fallos" ;;
  esac
fi

exit "$OVERALL"
