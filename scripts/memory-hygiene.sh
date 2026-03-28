#!/bin/bash
# memory-hygiene.sh — SPEC-142: Limpieza automática de auto-memory
# Ejecutar en background desde session-init para mantener MEMORY.md sano
# Modo: idempotente, no-destructivo, max 200 líneas en MEMORY.md
set -euo pipefail

MEMORY_DIR="${1:-$HOME/.claude/projects/-home-monica-claude/memory}"
MEMORY_INDEX="$MEMORY_DIR/MEMORY.md"
ARCHIVE_DIR="$MEMORY_DIR/archive"
MAX_INDEX_LINES=200
CUTOFF_DAYS=90
DRY_RUN="${DRY_RUN:-false}"
STATS_FILE="/tmp/memory-hygiene-stats.txt"

# Funciones de utilidad
log() { echo "[memory-hygiene] $*" >&2; }
is_dry_run() { [[ "$DRY_RUN" == "true" ]]; }

# Verificar que el directorio de memoria existe
if [[ ! -d "$MEMORY_DIR" ]]; then
  log "Directorio de memoria no encontrado: $MEMORY_DIR"
  exit 0
fi

archived=0
deduped=0
truncated=0

# ── 1. Archivar entradas antiguas (>CUTOFF_DAYS sin modificación) ─────────────
if [[ -d "$MEMORY_DIR" ]]; then
  while IFS= read -r -d '' mfile; do
    fname=$(basename "$mfile")
    [[ "$fname" == "MEMORY.md" ]] && continue
    [[ "$fname" == *.md ]] || continue

    # Calcular antigüedad en días
    mod_epoch=$(stat -c %Y "$mfile" 2>/dev/null || stat -f %m "$mfile" 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    age_days=$(( (now_epoch - mod_epoch) / 86400 ))

    if (( age_days > CUTOFF_DAYS )); then
      if ! is_dry_run; then
        mkdir -p "$ARCHIVE_DIR"
        mv "$mfile" "$ARCHIVE_DIR/${fname}"
        log "Archivado: $fname (${age_days}d sin modificar)"
      else
        log "[dry-run] Archivaría: $fname (${age_days}d)"
      fi
      (( archived++ )) || true
    fi
  done < <(find "$MEMORY_DIR" -maxdepth 1 -name "*.md" -not -name "MEMORY.md" -print0 2>/dev/null)
fi

# ── 2. Dedup de entradas en MEMORY.md (por nombre de fichero referenciado) ────
if [[ -f "$MEMORY_INDEX" ]]; then
  tmp_dedup=$(mktemp)
  seen=()
  dup_count=0

  while IFS= read -r line; do
    # Extraer referencia de fichero de líneas tipo: - [title](file.md) — ...
    ref=$(echo "$line" | grep -oP '\]\([^)]+\.md\)' | tr -d '()][' || true)
    if [[ -n "$ref" ]]; then
      already=false
      for s in "${seen[@]:-}"; do
        [[ "$s" == "$ref" ]] && already=true && break
      done
      if $already; then
        (( dup_count++ )) || true
        continue  # saltar duplicado
      fi
      seen+=("$ref")
    fi
    echo "$line" >> "$tmp_dedup"
  done < "$MEMORY_INDEX"

  if (( dup_count > 0 )); then
    if ! is_dry_run; then
      mv "$tmp_dedup" "$MEMORY_INDEX"
      log "Dedup: eliminadas $dup_count entradas duplicadas en MEMORY.md"
    else
      log "[dry-run] Dedup: eliminaría $dup_count duplicados"
      rm -f "$tmp_dedup"
    fi
    deduped=$dup_count
  else
    rm -f "$tmp_dedup"
  fi
fi

# ── 3. Truncar MEMORY.md si supera MAX_INDEX_LINES ───────────────────────────
if [[ -f "$MEMORY_INDEX" ]]; then
  line_count=$(wc -l < "$MEMORY_INDEX")
  if (( line_count > MAX_INDEX_LINES )); then
    excess=$(( line_count - MAX_INDEX_LINES ))
    if ! is_dry_run; then
      # Preservar cabecera (primera línea) y truncar desde el final
      head -n "$MAX_INDEX_LINES" "$MEMORY_INDEX" > "${MEMORY_INDEX}.tmp"
      mv "${MEMORY_INDEX}.tmp" "$MEMORY_INDEX"
      log "Truncado: MEMORY.md de ${line_count} a ${MAX_INDEX_LINES} líneas (eliminadas ${excess})"
    else
      log "[dry-run] Truncaría: ${line_count} → ${MAX_INDEX_LINES} líneas"
    fi
    truncated=$excess
  fi
fi

# ── 4. Eliminar referencias rotas en MEMORY.md (fichero no existe) ────────────
if [[ -f "$MEMORY_INDEX" ]]; then
  tmp_clean=$(mktemp)
  broken=0

  while IFS= read -r line; do
    # Detectar líneas con referencia a fichero
    ref=$(echo "$line" | grep -oP '\]\([^)]+\.md\)' | tr -d '()][' || true)
    if [[ -n "$ref" ]]; then
      target="$MEMORY_DIR/$ref"
      if [[ ! -f "$target" ]]; then
        (( broken++ )) || true
        log "Ref rota eliminada: $ref"
        continue  # omitir línea con ref rota
      fi
    fi
    echo "$line" >> "$tmp_clean"
  done < "$MEMORY_INDEX"

  if (( broken > 0 )); then
    if ! is_dry_run; then
      mv "$tmp_clean" "$MEMORY_INDEX"
    else
      log "[dry-run] Eliminaría $broken referencias rotas"
      rm -f "$tmp_clean"
    fi
  else
    rm -f "$tmp_clean"
  fi
fi

# ── 5. Resumen ────────────────────────────────────────────────────────────────
{
  echo "archived=$archived"
  echo "deduped=$deduped"
  echo "truncated=$truncated"
  echo "ran_at=$(date -Iseconds)"
} > "$STATS_FILE"

log "Higiene completada: archivados=${archived} deduped=${deduped} truncados=${truncated}"
exit 0
