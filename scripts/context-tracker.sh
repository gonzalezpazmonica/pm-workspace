#!/usr/bin/env bash
# ── context-tracker.sh ─────────────────────────────────────────────────────
# Tracking ligero de uso de contexto para /context-optimize
# Registra qué fragmentos se cargan en cada sesión sin almacenar datos de usuario
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

CONFIG_DIR="$HOME/.pm-workspace"
LOG_FILE="$CONFIG_DIR/context-usage.log"
MAX_LOG_SIZE=1048576  # 1MB máximo
MAX_LOG_ENTRIES=5000

# ── Funciones auxiliares ────────────────────────────────────────────────────

ensure_config_dir() {
  mkdir -p "$CONFIG_DIR"
}

# Rotar log si supera el tamaño máximo
rotate_log() {
  if [ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE")" -gt "$MAX_LOG_SIZE" ]; then
    # Mantener las últimas MAX_LOG_ENTRIES entradas
    tail -n "$MAX_LOG_ENTRIES" "$LOG_FILE" > "$LOG_FILE.tmp"
    mv "$LOG_FILE.tmp" "$LOG_FILE"
  fi
}

# ── Subcomandos ─────────────────────────────────────────────────────────────

# Registrar una entrada de uso
do_log() {
  local command="${1:-unknown}"
  local fragments="${2:-none}"
  local tokens_est="${3:-0}"

  ensure_config_dir
  rotate_log

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  echo "${timestamp}|${command}|${fragments}|${tokens_est}" >> "$LOG_FILE"
}

# Obtener estadísticas del log
do_stats() {
  if [ ! -f "$LOG_FILE" ]; then
    echo "NO_DATA"
    exit 0
  fi

  local total_entries
  total_entries=$(wc -l < "$LOG_FILE")

  local first_date last_date
  first_date=$(head -n 1 "$LOG_FILE" | cut -d'|' -f1)
  last_date=$(tail -n 1 "$LOG_FILE" | cut -d'|' -f1)

  local total_tokens
  total_tokens=$(awk -F'|' '{sum += $4} END {print sum}' "$LOG_FILE")

  echo "entries=${total_entries}"
  echo "period_start=${first_date}"
  echo "period_end=${last_date}"
  echo "tokens_total=${total_tokens}"
}

# Obtener ranking de comandos más usados
do_top_commands() {
  local limit="${1:-10}"

  if [ ! -f "$LOG_FILE" ]; then
    echo "NO_DATA"
    exit 0
  fi

  awk -F'|' '{print $2}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -n "$limit"
}

# Obtener ranking de fragmentos más cargados
do_top_fragments() {
  local limit="${1:-10}"

  if [ ! -f "$LOG_FILE" ]; then
    echo "NO_DATA"
    exit 0
  fi

  awk -F'|' '{n=split($3,a,","); for(i=1;i<=n;i++) print a[i]}' "$LOG_FILE" | \
    sed 's/^ *//;s/ *$//' | \
    grep -v '^none$' | \
    sort | uniq -c | sort -rn | head -n "$limit"
}

# Detectar co-ocurrencias (comandos ejecutados juntos en <5min)
do_cooccurrences() {
  if [ ! -f "$LOG_FILE" ]; then
    echo "NO_DATA"
    exit 0
  fi

  # Comparar pares consecutivos con diferencia < 300 segundos
  awk -F'|' '
  function parse_ts(ts) {
    gsub(/[-T:Z]/, " ", ts)
    return mktime(ts)
  }
  NR > 1 {
    t2 = parse_ts($1)
    if (t1 > 0 && (t2 - t1) < 300 && prev_cmd != $2) {
      pair = (prev_cmd < $2) ? prev_cmd "+" $2 : $2 "+" prev_cmd
      pairs[pair]++
    }
    t1 = t2
    prev_cmd = $2
  }
  NR == 1 {
    t1 = parse_ts($1)
    prev_cmd = $2
  }
  END {
    for (p in pairs) if (pairs[p] >= 3) print pairs[p], p
  }' "$LOG_FILE" | sort -rn | head -n 10
}

# Detectar fragmentos cargados pero posiblemente innecesarios
do_low_impact() {
  if [ ! -f "$LOG_FILE" ]; then
    echo "NO_DATA"
    exit 0
  fi

  # Fragmentos que se cargan en >50% de sesiones pero con baja variación de tokens
  echo "# Fragmentos cargados frecuentemente (revisar si son necesarios):"
  awk -F'|' '{n=split($3,a,","); for(i=1;i<=n;i++) {f=a[i]; gsub(/^ +| +$/,"",f); if(f!="none") frags[f]++}} END {for(f in frags) print frags[f], f}' "$LOG_FILE" | sort -rn
}

# Limpiar log
do_reset() {
  if [ -f "$LOG_FILE" ]; then
    local backup
    backup="$LOG_FILE.bak.$(date +%Y%m%d)"
    cp "$LOG_FILE" "$backup"
    > "$LOG_FILE"
    echo "RESET_OK|backup=${backup}"
  else
    echo "NO_LOG"
  fi
}

# ── Main ────────────────────────────────────────────────────────────────────

case "${1:-help}" in
  log)
    do_log "${2:-}" "${3:-}" "${4:-}"
    ;;
  stats)
    do_stats
    ;;
  top-commands)
    do_top_commands "${2:-10}"
    ;;
  top-fragments)
    do_top_fragments "${2:-10}"
    ;;
  cooccurrences)
    do_cooccurrences
    ;;
  low-impact)
    do_low_impact
    ;;
  reset)
    do_reset
    ;;
  help|*)
    echo "Usage: context-tracker.sh <subcommand>"
    echo ""
    echo "Subcommands:"
    echo "  log <cmd> <fragments> <tokens>  — Register context usage"
    echo "  stats                           — Show usage statistics"
    echo "  top-commands [N]                — Top N most used commands"
    echo "  top-fragments [N]               — Top N most loaded fragments"
    echo "  cooccurrences                   — Command co-occurrence patterns"
    echo "  low-impact                      — Potentially unnecessary fragments"
    echo "  reset                           — Clear log (with backup)"
    ;;
esac
