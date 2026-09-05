#!/usr/bin/env bash
# SE-387 F — Transición IMPLEMENTING->IMPLEMENTED solo si evidencia machine-checkable.
# Uso: planning-transition.sh check <ID>   (evidencia: PR mergeado + artefactos presentes)
set -uo pipefail
ROOT="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
STATE="$ROOT/docs/propuestas/planning-state.json"
ID="${2:-}"
jq -e --arg id "$ID" '.initiatives[]|select(.id==$id)' "$STATE" >/dev/null || { echo "FAIL: $ID no existe"; exit 1; }
ST=$(jq -r --arg id "$ID" '.initiatives[]|select(.id==$id)|.status' "$STATE")
EV=$(jq -r --arg id "$ID" '.initiatives[]|select(.id==$id)|.evidence // ""' "$STATE")
PR=$(echo "$EV" | grep -oP 'PR #\d+' | head -1 | tr -d '#' )
if [[ "$ST" == "IMPLEMENTING" && -n "$PR" ]] && git -C "$ROOT" log --oneline origin/main -50 | grep -q "#$PR"; then
  echo "NEEDS_HUMAN_REVIEW: evidencia PR #$PR presente; cierre final requiere revisión humana"
  exit 0
fi
echo "IMPLEMENTING (sin PR mergeado verificable en evidencia)"; exit 1
