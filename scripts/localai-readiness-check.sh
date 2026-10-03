#!/usr/bin/env bash
# localai-readiness-check.sh — SPEC-122
# Verifica que LocalAI (https://github.com/mudler/LocalAI) está listo para
# servir como fallback Anthropic API shim cuando la cloud API cae.
#
# Usage:
#   bash scripts/localai-readiness-check.sh [--url URL] [--model MODEL] [--json]
#
# Env:
#   LOCALAI_URL     default http://localhost:8080 (barra final eliminada)
#   LOCALAI_MODEL   default claude-compatible-local (id exacto en /v1/models)
#   LOCALAI_RAM_OK_GB / LOCALAI_RAM_MIN_GB    umbrales RAM, default 16 / 8
#   LOCALAI_DISK_OK_GB / LOCALAI_DISK_MIN_GB  umbrales disco libre, default 20 / 5
#   LOCALAI_MEMINFO, LOCALAI_DISK_PATH        fuentes medidas (default /proc/meminfo, $HOME)
#
# Exit codes:
#   0 = READY (all checks OK)
#   1 = WARNING (non-blocking: RAM/disco justos o no medidos)
#   2 = FAIL (LocalAI caído / sin /v1/messages / modelo pedido no cargado) or usage error
#
# Requiere jq. Switchover (decisión humana), solo si exit < 2:
#   ANTHROPIC_BASE_URL=<LOCALAI_URL> (sin /v1: Claude Code añade /v1/messages),
#   ANTHROPIC_MODEL y ANTHROPIC_SMALL_FAST_MODEL=<LOCALAI_MODEL>.

set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "Error: jq is required" >&2; exit 2; }

LOCALAI_URL="${LOCALAI_URL:-http://localhost:8080}"
LOCALAI_MODEL="${LOCALAI_MODEL:-claude-compatible-local}"
OUTPUT_JSON=false
MIN_VERSION="3.10.0"  # Anthropic API compat desde v3.10.0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url|--model)
      [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || { echo "Error: $1 needs a value" >&2; exit 2; }
      if [[ "$1" == "--url" ]]; then LOCALAI_URL="$2"; else LOCALAI_MODEL="$2"; fi
      shift 2 ;;
    --json) OUTPUT_JSON=true; shift ;;
    --help|-h)
      sed -n '2,23p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *)
      echo "Error: unknown option $1" >&2
      exit 2 ;;
  esac
done

# Barra final fuera, venga de --url o de LOCALAI_URL: evita //v1/messages.
while [[ "$LOCALAI_URL" == */ ]]; do LOCALAI_URL="${LOCALAI_URL%/}"; done

RAM_OK_GB="${LOCALAI_RAM_OK_GB:-16}"
RAM_MIN_GB="${LOCALAI_RAM_MIN_GB:-8}"
DISK_OK_GB="${LOCALAI_DISK_OK_GB:-20}"
DISK_MIN_GB="${LOCALAI_DISK_MIN_GB:-5}"
for t in RAM_OK_GB RAM_MIN_GB DISK_OK_GB DISK_MIN_GB; do
  [[ "${!t}" =~ ^[0-9]+$ ]] || { echo "Error: LOCALAI_$t must be a non-negative integer" >&2; exit 2; }
done
MEMINFO="${LOCALAI_MEMINFO:-/proc/meminfo}"
DISK_PATH="${LOCALAI_DISK_PATH:-$HOME}"

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

# Entre comillas dobles y seguro para pegar en bash: escapa \ " $ y `.
dquote() {
  local v="$1"
  v="${v//\\/\\\\}"; v="${v//\"/\\\"}"; v="${v//\$/\\\$}"; v="${v//\`/\\\`}"
  printf '"%s"' "$v"
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
  # Ids exactos de /v1/models (OpenAI-compatible: {"data":[{"id":…}]}); sin regex sobre el nombre.
  local ids
  ids=$(printf '%s' "$models_json" | jq -r '.data[]?.id // empty' 2>/dev/null)
  if [[ -n "$ids" ]] && printf '%s\n' "$ids" | grep -qxF -- "$LOCALAI_MODEL"; then
    record "OK" "model_available" "Model '$LOCALAI_MODEL' loaded"
    return 0
  fi
  # Check ANY model loaded
  # Otro modelo cargado no basta: Claude Code pediría '$LOCALAI_MODEL' y fallaría la primera petición.
  if [[ -n "$ids" ]]; then
    record "FAIL" "model_available" "Model '$LOCALAI_MODEL' NOT loaded; loaded: $(printf '%s' "$ids" | paste -sd, -) — re-run with --model <loaded id>"
    return 1
  fi
  record "FAIL" "model_available" "NO models loaded in LocalAI"
  return 1
}

check_ram() {
  local ram_kb="" bytes
  if [[ -r "$MEMINFO" ]]; then
    ram_kb=$(awk '/MemTotal/{print $2}' "$MEMINFO" 2>/dev/null)
  elif bytes=$(sysctl -n hw.memsize 2>/dev/null) && [[ "$bytes" =~ ^[0-9]+$ ]]; then
    ram_kb=$(( bytes / 1024 ))  # macOS
  fi
  if ! [[ "$ram_kb" =~ ^[0-9]+$ ]]; then
    record "WARN" "ram" "RAM no medido (sin $MEMINFO ni sysctl hw.memsize)"
    return 0
  fi
  local ram_gb=$(( ram_kb / 1024 / 1024 ))
  if (( ram_gb >= RAM_OK_GB )); then
    record "OK" "ram" "RAM ${ram_gb}GB (sufficient for 4-bit 7-13B models)"
  elif (( ram_gb >= RAM_MIN_GB )); then
    record "WARN" "ram" "RAM ${ram_gb}GB (limited — use 4-bit small models only)"
  else
    record "FAIL" "ram" "RAM ${ram_gb}GB insufficient (<${RAM_MIN_GB}GB)"
  fi
}

check_disk() {
  # df -Pk es POSIX (GNU y macOS): columna 4 = KiB disponibles.
  local free_gb
  free_gb=$(df -Pk "$DISK_PATH" 2>/dev/null | awk 'NR==2{print int($4/1024/1024)}')
  if ! [[ "$free_gb" =~ ^[0-9]+$ ]]; then
    record "WARN" "disk" "Disk free no medido (df falla en $DISK_PATH)"
    return 0
  fi
  if (( free_gb >= DISK_OK_GB )); then
    record "OK" "disk" "Disk free ${free_gb}GB"
  elif (( free_gb >= DISK_MIN_GB )); then
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
  for c in "${CHECKS[@]}"; do
    IFS='|' read -r status check msg <<< "$c"
    jq -nc --arg s "$status" --arg c "$check" --arg m "$msg" '{status:$s, check:$c, message:$m}'
  done | jq -sc --argjson o "$OVERALL" --arg u "$LOCALAI_URL" --arg m "$LOCALAI_MODEL" \
    '{overall:$o, checks:., switchover:{ANTHROPIC_BASE_URL:$u, ANTHROPIC_MODEL:$m, ANTHROPIC_SMALL_FAST_MODEL:$m}}'
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
  if (( OVERALL < 2 )); then
    echo ""
    echo "Switchover (decisión humana, sin /v1: Claude Code añade /v1/messages):"
    printf '  export ANTHROPIC_BASE_URL=%s\n' "$(dquote "$LOCALAI_URL")"
    printf '  export ANTHROPIC_MODEL=%s\n' "$(dquote "$LOCALAI_MODEL")"
    printf '  export ANTHROPIC_SMALL_FAST_MODEL=%s\n' "$(dquote "$LOCALAI_MODEL")"
  fi
fi

exit "$OVERALL"
