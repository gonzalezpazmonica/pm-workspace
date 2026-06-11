#!/bin/bash
# memory-hygiene.sh — SPEC-142: Limpieza automática de auto-memory
# Ejecutar en background desde session-init para mantener MEMORY.md sano
# Modo: idempotente, no-destructivo, max 200 líneas en MEMORY.md
#
# SE-073 alignment: path canónico es ~/.savia-memory/auto/ (no el legacy
# ~/.claude/projects/-home-monica-claude/memory). Si se pasa un argumento
# explícito, se respeta; en otro caso, se usa el canónico actual.
set -euo pipefail

MEMORY_DIR="${1:-${SAVIA_MEMORY_DIR:-$HOME/.savia-memory}/auto}"
MEMORY_INDEX="$MEMORY_DIR/MEMORY.md"
ARCHIVE_DIR="$MEMORY_DIR/archive"
MAX_INDEX_LINES="${MEMORY_INDEX_SOFT_CAP:-200}"
CUTOFF_DAYS=90
DRY_RUN="${DRY_RUN:-false}"
STATS_FILE="/tmp/memory-hygiene-stats.txt"
log() { echo "[memory-hygiene] $*" >&2; }
is_dry_run() { [[ "$DRY_RUN" == "true" ]]; }
if [[ ! -d "$MEMORY_DIR" ]]; then
  log "Directorio de memoria no encontrado: $MEMORY_DIR"
  exit 0
fi

archived=0
deduped=0
truncated=0

# ── 1. Archivar entradas antiguas (>CUTOFF_DAYS) ──
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
      fi
      log "Archivado: $fname (${age_days}d)"
      (( archived++ )) || true
    fi
  done < <(find "$MEMORY_DIR" -maxdepth 1 -name "*.md" -not -name "MEMORY.md" -print0 2>/dev/null)
fi

# ── 2. Dedup en MEMORY.md (por topic_key entre brackets) ──
#
# Formato canónico de entrada: "- {type}: {title} [{topic_key}]"
# Mantener PRIMERA aparición (top = más reciente; nuevas se insertan al inicio).
if [[ -f "$MEMORY_INDEX" ]]; then
  tmp_dedup=$(mktemp)
  dup_count=$(python3 - "$MEMORY_INDEX" "$tmp_dedup" <<'PY' 2>/dev/null || echo 0
import re, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, 'r', encoding='utf-8') as f:
    lines = f.readlines()
seen = set()
out = []
in_block = False
dup = 0
key_re = re.compile(r'\[([^\[\]]+)\]\s*$')
for ln in lines:
    s = ln.rstrip('\n')
    if s == '<!-- ENTRIES_START -->':
        in_block = True
        out.append(ln)
        continue
    if s == '<!-- ENTRIES_END -->':
        in_block = False
        out.append(ln)
        continue
    if in_block and s.lstrip().startswith('- '):
        m = key_re.search(s)
        if m:
            key = m.group(1)
            if key in seen:
                dup += 1
                continue
            seen.add(key)
        out.append(ln)
        continue
    out.append(ln)
with open(dst, 'w', encoding='utf-8') as f:
    f.writelines(out)
print(dup)
PY
)
  dup_count="${dup_count:-0}"

  if (( dup_count > 0 )); then
    if ! is_dry_run; then
      mv "$tmp_dedup" "$MEMORY_INDEX"
      log "Dedup: $dup_count duplicados eliminados (por topic_key)"
      deduped=$dup_count
    else
      log "[dry-run] Eliminaria $dup_count duplicados (por topic_key)"
      rm -f "$tmp_dedup"
      deduped=$dup_count
    fi
  else
    rm -f "$tmp_dedup"
  fi
fi

# ── 3. Truncar si supera MAX_INDEX_LINES ──
if [[ -f "$MEMORY_INDEX" ]]; then
  line_count=$(wc -l < "$MEMORY_INDEX")
  if (( line_count > MAX_INDEX_LINES )) && ! is_dry_run; then
    truncated=$(( line_count - MAX_INDEX_LINES ))
    head -n "$MAX_INDEX_LINES" "$MEMORY_INDEX" > "${MEMORY_INDEX}.tmp"
    mv "${MEMORY_INDEX}.tmp" "$MEMORY_INDEX"
    log "Truncado: ${line_count} → ${MAX_INDEX_LINES} lineas"
  fi
fi

# ── 4. Eliminar refs rotas ──
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

# ── 5. 25KB limit + trim >150 chars ──
if [[ -f "$MEMORY_INDEX" ]]; then
  size_bytes=$(stat -c%s "$MEMORY_INDEX" 2>/dev/null || stat -f%z "$MEMORY_INDEX" 2>/dev/null || echo 0)
  if (( size_bytes > 25600 )) && ! is_dry_run; then
    while (( size_bytes > 25600 )) && (( $(wc -l < "$MEMORY_INDEX") > 10 )); do
      head -n -3 "$MEMORY_INDEX" > "${MEMORY_INDEX}.trim" && mv "${MEMORY_INDEX}.trim" "$MEMORY_INDEX"
      size_bytes=$(stat -c%s "$MEMORY_INDEX" 2>/dev/null || stat -f%z "$MEMORY_INDEX" 2>/dev/null || echo 0)
    done
    log "Trimmed MEMORY.md to ${size_bytes} bytes (25KB limit)"
  fi
  if ! is_dry_run && awk 'length > 150' "$MEMORY_INDEX" | grep -q .; then
    awk '{ if (length > 150) print substr($0, 1, 147) "..."; else print }' "$MEMORY_INDEX" > "${MEMORY_INDEX}.short"
    mv "${MEMORY_INDEX}.short" "$MEMORY_INDEX"
    log "Trimmed entries exceeding 150 chars"
  fi
fi

# ── 6. Resumen ──
{
  echo "archived=$archived"
  echo "deduped=$deduped"
  echo "truncated=$truncated"
  echo "ran_at=$(date -Iseconds)"
} > "$STATS_FILE"

log "Higiene completada: archivados=${archived} deduped=${deduped} truncados=${truncated}"
exit 0
