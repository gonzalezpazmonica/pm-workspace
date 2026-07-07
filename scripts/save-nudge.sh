#!/usr/bin/env bash
# scripts/save-nudge.sh — SE-256 Slice 1
# PostToolUse hook: recuerda cada ~15 min registrar eventos en el libro de la relacion.
# Debounce: solo emite si hubo overrides/edit/revert desde el ultimo nudge.
# No bloquea: exit 0 siempre.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
STATE_FILE="${HOME}/.savia/nudge-state"
mkdir -p "$(dirname "$STATE_FILE")"

# ── Config ──────────────────────────────────────────────────────────────
NUDGE_INTERVAL=$((15 * 60))  # 15 minutos en segundos
NOW=$(date +%s)

# ── Leer estado anterior ────────────────────────────────────────────────
LAST_NUDGE=0
EVENTS_SINCE=0
if [[ -f "$STATE_FILE" ]]; then
  LAST_NUDGE=$(head -1 "$STATE_FILE" 2>/dev/null || echo 0)
  EVENTS_SINCE=$(sed -n '2p' "$STATE_FILE" 2>/dev/null || echo 0)
fi

# ── Detectar si hubo overrides/edit/revert no registrados ────────────────
# Chequeo heuristico: buscar ficheros modificados en drafts/ o output/
# que sugieran decision no capturada
NEW_EVENTS=0
DRAFTS_DIR="${ROOT}/drafts"
if [[ -d "$DRAFTS_DIR" ]]; then
  RECENT=$(find "$DRAFTS_DIR" -newer "$STATE_FILE" -type f 2>/dev/null | wc -l) || RECENT=0
  NEW_EVENTS=$((NEW_EVENTS + RECENT))
fi

if [[ -d "$ROOT/output" ]]; then
  RECENT=$(find "$ROOT/output" -newer "$STATE_FILE" -type f -name "*.md" 2>/dev/null | wc -l) || RECENT=0
  NEW_EVENTS=$((NEW_EVENTS + RECENT))
fi

# Actualizar contador de eventos
EVENTS_SINCE=$((EVENTS_SINCE + NEW_EVENTS))

# Guardar estado
echo "$LAST_NUDGE" > "$STATE_FILE"
echo "$EVENTS_SINCE" >> "$STATE_FILE"

# ── Decidir si emitir nudge ──────────────────────────────────────────────
ELAPSED=$((NOW - LAST_NUDGE))

if [[ $ELAPSED -ge $NUDGE_INTERVAL && $EVENTS_SINCE -gt 0 ]]; then
  echo "---"
  echo "📝 Han pasado ~$((ELAPSED / 60))min desde el ultimo registro."
  echo "   Hay $EVENTS_SINCE eventos potenciales sin capturar en el libro de la relacion."
  echo "   ¿Registrar? bash scripts/relacion-capture.sh <tipo> <texto>"
  echo "   Tipos: override, error_reconocido, acierto_verificado, no_se_declarado"
  echo ""

  # Resetear: actualizar timestamp y contador
  echo "$NOW" > "$STATE_FILE"
  echo "0" >> "$STATE_FILE"
fi

exit 0
