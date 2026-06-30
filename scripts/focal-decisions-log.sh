#!/usr/bin/env bash
# focal-decisions-log.sh — Audit trail append-only de decisiones del director (SE-230 Slice 2)
# Usage: focal-decisions-log.sh --nido <n> --decision <tipo> --context "ctx" --rationale "why"
set -uo pipefail

SAVIA_DIR="${HOME}/.savia"
FOCAL_DIR="${SAVIA_DIR}/focal-state"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../output"
LOG_FILE="${OUTPUT_DIR}/focal-decisions.jsonl"
LOCK_FILE="${OUTPUT_DIR}/focal-decisions.lock"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$FOCAL_DIR"

# ── Parse args ────────────────────────────────────────────────────────────────
NIDO=""
DECISION=""
CONTEXT=""
RATIONALE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --nido)      NIDO="$2";      shift 2 ;;
    --decision)  DECISION="$2";  shift 2 ;;
    --context)   CONTEXT="$2";   shift 2 ;;
    --rationale) RATIONALE="$2"; shift 2 ;;
    *)           shift ;;
  esac
done

if [[ -z "$NIDO" || -z "$DECISION" ]]; then
  echo "ERROR: --nido y --decision son obligatorios" >&2
  exit 1
fi

_now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# ── Calcular content_hash ─────────────────────────────────────────────────────
STATE_FILE="${FOCAL_DIR}/${NIDO}.json"
content_hash=""
if [[ -f "$STATE_FILE" ]]; then
  # Usar last_commit_hash del estado focal
  json=$(cat "$STATE_FILE" 2>/dev/null) || json="{}"
  # Extraer last_commit_hash
  content_hash=$(printf '%s' "$json" | grep -oP '"last_commit_hash"\s*:\s*"\K[^"]*' 2>/dev/null || true)
  if [[ -z "$content_hash" ]]; then
    # Fallback: sha256 del estado completo
    content_hash=$(printf '%s' "$json" | sha256sum 2>/dev/null | awk '{print substr($1,1,8)}' || echo "")
  fi
fi
[[ -z "$content_hash" ]] && content_hash="unknown"

now=$(_now_iso)

# ── Construir línea JSONL ─────────────────────────────────────────────────────
entry="{\"ts\":\"$(_esc "$now")\",\"nido\":\"$(_esc "$NIDO")\",\"decision\":\"$(_esc "$DECISION")\",\"context\":\"$(_esc "$CONTEXT")\",\"rationale\":\"$(_esc "$RATIONALE")\",\"content_hash\":\"$(_esc "$content_hash")\"}"

# ── Append con flock ──────────────────────────────────────────────────────────
(
  flock -w 5 200 || { echo "ERROR: flock timeout en focal-decisions-log" >&2; exit 1; }
  printf '%s\n' "$entry" >> "$LOG_FILE"
) 200>"$LOCK_FILE"

echo "Decisión registrada: ${DECISION} para nido ${NIDO}"
exit 0
