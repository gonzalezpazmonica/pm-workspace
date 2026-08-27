#!/usr/bin/env bash
# fronesis-gate-reminder.sh — SE-348 P3: recordatorio de punto de frónesis (SE-344).
# PostToolUse warn-only sobre PR/merge: recuerda consultar precedentes de juicio
# (fronema.py query) antes de una decisión con consecuencias. NUNCA bloquea.
set -uo pipefail
[[ "${SAVIA_FRONESIS_REMINDER:-on}" == "off" ]] && exit 0

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRO="$ROOT/scripts/fronema.py"
[[ -f "$FRO" ]] || exit 0
VAULT="${SAVIA_FRONESIS_VAULT:-$ROOT/vaults/Fronesia}"
[[ -d "$VAULT" ]] || exit 0

# Puntos de frónesis típicos: PR create / merge / push de rama con consecuencias
echo "[fronesis] Punto de frónesis detectado. ¿Consulta precedentes? (opcional)"
echo "  bash scripts/fronema.py query --tension \"<tu tensión>\" --vault $VAULT"
echo "  (los agentes traen precedentes; no deciden — SE-344)"
exit 0
