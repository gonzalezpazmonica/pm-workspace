#!/usr/bin/env bash
# ── context-aging.sh ───────────────────────────────────────────────────────
# Envejecimiento semántico del decision-log.md
# Comprime decisiones antiguas según su edad:
#   < 30 días: episódica (completa)
#   30-90 días: comprimida (una línea)
#   > 90 días: archivable (migrar a regla o archivar)
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Configuración ───────────────────────────────────────────────────────────
WORKSPACE_ROOT="${PM_WORKSPACE_ROOT:-$HOME/claude}"
DECISION_LOG="$WORKSPACE_ROOT/decision-log.md"
ARCHIVE_DIR="$WORKSPACE_ROOT/.decision-archive"
NOW_EPOCH=$(date +%s)
DAYS_COMPRESS=30
DAYS_ARCHIVE=90

# ── Funciones auxiliares ────────────────────────────────────────────────────

date_to_epoch() {
  local datestr="$1"
  # Acepta YYYY-MM-DD
  date -d "$datestr" +%s 2>/dev/null || echo "0"
}

days_ago() {
  local epoch="$1"
  if [ "$epoch" -eq 0 ]; then
    echo "999"
    return
  fi
  echo $(( (NOW_EPOCH - epoch) / 86400 ))
}

ensure_archive() {
  mkdir -p "$ARCHIVE_DIR"
}

# ── Análisis ────────────────────────────────────────────────────────────────

# Analizar decision-log y clasificar entradas por edad
do_analyze() {
  if [ ! -f "$DECISION_LOG" ]; then
    echo "NO_LOG|decision-log.md no encontrado en $WORKSPACE_ROOT"
    exit 0
  fi

  local total=0 fresh=0 compress=0 archive=0

  # Buscar entradas con patrón de fecha (## YYYY-MM-DD o **Fecha**: YYYY-MM-DD)
  while IFS= read -r line; do
    local datestr=""
    # Patrón 1: ## 2026-01-15 — Decisión sobre X
    if [[ "$line" =~ ^##[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
      datestr="${BASH_REMATCH[1]}"
    # Patrón 2: **Fecha**: 2026-01-15
    elif [[ "$line" =~ Fecha.*([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
      datestr="${BASH_REMATCH[1]}"
    # Patrón 3: - 2026-01-15: Decisión
    elif [[ "$line" =~ ^-[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
      datestr="${BASH_REMATCH[1]}"
    else
      continue
    fi

    local epoch
    epoch=$(date_to_epoch "$datestr")
    local age
    age=$(days_ago "$epoch")

    total=$((total + 1))

    if [ "$age" -lt "$DAYS_COMPRESS" ]; then
      fresh=$((fresh + 1))
    elif [ "$age" -lt "$DAYS_ARCHIVE" ]; then
      compress=$((compress + 1))
    else
      archive=$((archive + 1))
    fi
  done < "$DECISION_LOG"

  echo "total=$total"
  echo "fresh=$fresh"
  echo "compress=$compress"
  echo "archive=$archive"
}

# Ejecutar compresión (modo dry-run por defecto)
do_compress() {
  local dry_run="${1:-true}"

  if [ ! -f "$DECISION_LOG" ]; then
    echo "NO_LOG"
    exit 0
  fi

  local compressed=0

  echo "# Entradas comprimibles (${DAYS_COMPRESS}-${DAYS_ARCHIVE} días):"
  echo ""

  while IFS= read -r line; do
    local datestr=""
    if [[ "$line" =~ ^##[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
      datestr="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^-[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
      datestr="${BASH_REMATCH[1]}"
    else
      continue
    fi

    local epoch
    epoch=$(date_to_epoch "$datestr")
    local age
    age=$(days_ago "$epoch")

    if [ "$age" -ge "$DAYS_COMPRESS" ] && [ "$age" -lt "$DAYS_ARCHIVE" ]; then
      compressed=$((compressed + 1))
      echo "  [$datestr] (${age}d) $line"
    fi
  done < "$DECISION_LOG"

  echo ""
  echo "compressible=$compressed"
  if [ "$dry_run" = "true" ]; then
    echo "mode=dry_run (usa 'apply' para ejecutar)"
  fi
}

# Listar entradas archivables
do_archivable() {
  if [ ! -f "$DECISION_LOG" ]; then
    echo "NO_LOG"
    exit 0
  fi

  local archivable=0

  echo "# Entradas archivables (>${DAYS_ARCHIVE} días):"
  echo ""

  while IFS= read -r line; do
    local datestr=""
    if [[ "$line" =~ ^##[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
      datestr="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^-[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
      datestr="${BASH_REMATCH[1]}"
    else
      continue
    fi

    local epoch
    epoch=$(date_to_epoch "$datestr")
    local age
    age=$(days_ago "$epoch")

    if [ "$age" -ge "$DAYS_ARCHIVE" ]; then
      archivable=$((archivable + 1))
      echo "  [$datestr] (${age}d) $line"
    fi
  done < "$DECISION_LOG"

  echo ""
  echo "archivable=$archivable"
}

# Archivar entradas antiguas
do_archive() {
  if [ ! -f "$DECISION_LOG" ]; then
    echo "NO_LOG"
    exit 0
  fi

  ensure_archive
  local archive_file="$ARCHIVE_DIR/decisions-$(date +%Y%m%d).md"
  local archived=0

  echo "# Archived Decisions — $(date +%Y-%m-%d)" > "$archive_file"
  echo "" >> "$archive_file"

  # Copiar entradas archivables al archivo
  local in_archivable=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
      local datestr="${BASH_REMATCH[1]}"
      local epoch
      epoch=$(date_to_epoch "$datestr")
      local age
      age=$(days_ago "$epoch")

      if [ "$age" -ge "$DAYS_ARCHIVE" ]; then
        in_archivable=true
        archived=$((archived + 1))
      else
        in_archivable=false
      fi
    fi

    if [ "$in_archivable" = true ]; then
      echo "$line" >> "$archive_file"
    fi
  done < "$DECISION_LOG"

  echo "archived=$archived"
  echo "archive_file=$archive_file"
}

# ── Main ────────────────────────────────────────────────────────────────────

case "${1:-help}" in
  analyze)
    do_analyze
    ;;
  compress)
    do_compress "${2:-true}"
    ;;
  archivable)
    do_archivable
    ;;
  archive)
    do_archive
    ;;
  help|*)
    echo "Usage: context-aging.sh <subcommand>"
    echo ""
    echo "Subcommands:"
    echo "  analyze              — Count entries by age category"
    echo "  compress [dry|apply] — Show/apply compression of 30-90 day entries"
    echo "  archivable           — List entries older than 90 days"
    echo "  archive              — Move old entries to .decision-archive/"
    ;;
esac
