#!/usr/bin/env bash
# savia-bootstrap-log.sh — SPEC-CONSOLIDACION R3: log de instalación/arranque.
#
# Registra cada paso del bootstrap (instalador, hooks, sesión) en un log
# append-only injestable por el propio arranque para auto-corrección.
#
#   output/install-logs/YYYYMMDD-install.tsv   — append por día (paso, exit, ts, msg)
#   .savia/install.log                          — last 200 líneas (rotativo)
#
# Nunca rompe el arranque: exit 0 siempre (RN-02).
#
# Usage:
#   savia-bootstrap-log.sh write <step> <exit_code> [message]
#   savia-bootstrap-log.sh recent [N]
# Exit: 0 siempre
set -uo pipefail

ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOG_DIR="$ROOT/output/install-logs"
ROTATE_LOG="${SAVIA_INSTALL_LOG:-$HOME/.savia/install.log}"
ACTION="${1:-recent}"
STEP="${2:-}"
CODE="${3:-0}"
MSG="${4:-}"

mkdir -p "$LOG_DIR" 2>/dev/null || true

iso_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "?"; }

case "$ACTION" in
  write)
    if [[ -z "$STEP" ]]; then
      echo "usage: savia-bootstrap-log.sh write <step> <exit_code> [message]" >&2
      exit 0
    fi
    day_file="$LOG_DIR/$(date -u +%Y%m%d)-install.tsv"
    printf '%s\t%s\t%s\t%s\n' "$(iso_ts)" "$STEP" "$CODE" "$MSG" >> "$day_file" 2>/dev/null || true
    printf '%s\t%s\t%s\t%s\n' "$(iso_ts)" "$STEP" "$CODE" "$MSG" >> "$ROTATE_LOG" 2>/dev/null || true
    # Rotar a 200 líneas (mantener cola)
    if [[ -f "$ROTATE_LOG" ]]; then
      tail -n 200 "$ROTATE_LOG" > "$ROTATE_LOG.tmp" 2>/dev/null && mv "$ROTATE_LOG.tmp" "$ROTATE_LOG" 2>/dev/null || true
    fi
    echo "logged: $STEP exit=$CODE → $day_file"
    ;;
  recent)
    N="${2:-20}"
    echo "── Recent install log (last $N) ──"
    tail -n "$N" "$ROTATE_LOG" 2>/dev/null || echo "(no log yet)"
    ;;
  *)
    echo "usage: savia-bootstrap-log.sh {write|recent} [args]" >&2
    exit 0
    ;;
esac
exit 0