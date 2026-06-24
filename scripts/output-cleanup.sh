#!/usr/bin/env bash
# output-cleanup.sh — Rotación de ficheros en output/ según política SE-101
# Política canónica: docs/rules/domain/output-retention.md
#
# Uso:
#   --dry-run   Lista qué se borraría (nunca borra)
#   --apply     Aplica el borrado real
#   --stats     Muestra tamaño total de output/ y conteo de ficheros
#   --help      Muestra esta ayuda
#
# IMPORTANTE: Sin --apply no se borra nada.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/output"

# ── Política de retención (días) ─────────────────────────────────────────────
RETENTION_DEFAULT=90
RETENTION_AGENT_RUNS=7
RETENTION_BASELINES=0        # 0 = indefinida (nunca borrar)
RETENTION_RESEARCH=180
RETENTION_POSTMORTEMS=0      # 0 = indefinida (nunca borrar)

# ── Parseo de flags ──────────────────────────────────────────────────────────
DRY_RUN=false
APPLY=false
STATS=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY_RUN=true ;;
    --apply)    APPLY=true ;;
    --stats)    STATS=true ;;
    --help|-h)
      echo "output-cleanup.sh — Política SE-101"
      echo ""
      echo "Uso:"
      echo "  --dry-run   Lista ficheros candidatos a borrado (sin borrar)"
      echo "  --apply     Aplica rotación según política de retención"
      echo "  --stats     Muestra tamaño total y conteo de ficheros en output/"
      echo "  --help      Muestra esta ayuda"
      echo ""
      echo "IMPORTANTE: Sin --apply no se borra nada."
      exit 0
      ;;
    *)
      echo "Flag desconocido: $arg" >&2
      echo "Usa --help para ver las opciones disponibles." >&2
      exit 1
      ;;
  esac
done

# ── Sin flag operativo: mostrar ayuda ────────────────────────────────────────
if ! $DRY_RUN && ! $APPLY && ! $STATS; then
  echo "output-cleanup.sh — Política SE-101"
  echo ""
  echo "Uso:"
  echo "  --dry-run   Lista ficheros candidatos a borrado (sin borrar)"
  echo "  --apply     Aplica rotación según política de retención"
  echo "  --stats     Muestra tamaño total y conteo de ficheros en output/"
  echo "  --help      Muestra esta ayuda"
  echo ""
  echo "IMPORTANTE: Sin --apply no se borra nada."
  exit 0
fi

# ── Stats ────────────────────────────────────────────────────────────────────
if $STATS; then
  echo "=== output/ stats ==="
  du -sh "$OUTPUT_DIR" 2>/dev/null || echo "(output/ no encontrado)"
  total=$(find "$OUTPUT_DIR" -type f 2>/dev/null | wc -l)
  echo "Ficheros totales: $total"
  echo ""
  echo "Por subdirectorio:"
  for subdir in "$OUTPUT_DIR"/*/; do
    [ -d "$subdir" ] || continue
    name=$(basename "$subdir")
    count=$(find "$subdir" -type f 2>/dev/null | wc -l)
    size=$(du -sh "$subdir" 2>/dev/null | cut -f1)
    echo "  $name/: $count ficheros, $size"
  done
fi

# ── Función: obtener edad del fichero en días ─────────────────────────────────
file_age_days() {
  local filepath="$1"
  local now
  now=$(date +%s)

  # Intentar fecha de creación git (primer commit que añadió el fichero)
  local rel_path
  rel_path="${filepath#$ROOT_DIR/}"
  local git_date
  git_date=$(cd "$ROOT_DIR" && git log --diff-filter=A --follow --format="%at" -- "$rel_path" 2>/dev/null | tail -1)

  if [[ -n "$git_date" && "$git_date" =~ ^[0-9]+$ ]]; then
    echo $(( (now - git_date) / 86400 ))
  else
    # Fallback: mtime del sistema
    local mtime
    mtime=$(stat --format="%Y" "$filepath" 2>/dev/null || stat -f "%m" "$filepath" 2>/dev/null || echo "0")
    echo $(( (now - mtime) / 86400 ))
  fi
}

# ── Función: retención para un fichero dado su path ─────────────────────────
get_retention() {
  local filepath="$1"
  local rel_path="${filepath#$OUTPUT_DIR/}"

  # Excepción: nombre contiene "keep" → retención indefinida
  local basename
  basename=$(basename "$filepath")
  if [[ "$basename" == *keep* ]]; then
    echo 0
    return
  fi

  # Por subdirectorio
  case "$rel_path" in
    agent-runs/*)   echo "$RETENTION_AGENT_RUNS" ;;
    baselines/*)    echo "$RETENTION_BASELINES" ;;
    research/*)     echo "$RETENTION_RESEARCH" ;;
    postmortems/*)  echo "$RETENTION_POSTMORTEMS" ;;
    *)              echo "$RETENTION_DEFAULT" ;;
  esac
}

# ── Dry-run o Apply ───────────────────────────────────────────────────────────
if $DRY_RUN || $APPLY; then
  mode_label="DRY-RUN"
  $APPLY && mode_label="APPLY"

  echo "=== output-cleanup [$mode_label] — $(date '+%Y-%m-%d %H:%M') ==="
  echo ""

  deleted=0
  skipped=0
  candidates=0

  while IFS= read -r -d '' filepath; do
    # Solo ficheros
    [ -f "$filepath" ] || continue

    retention=$(get_retention "$filepath")

    # Retención 0 = indefinida, nunca borrar
    if [[ "$retention" -eq 0 ]]; then
      skipped=$(( skipped + 1 ))
      continue
    fi

    age=$(file_age_days "$filepath")

    if [[ "$age" -ge "$retention" ]]; then
      candidates=$(( candidates + 1 ))
      rel="${filepath#$ROOT_DIR/}"
      echo "  CANDIDATO (${age}d >= ${retention}d): $rel"

      if $APPLY; then
        rm -f "$filepath"
        deleted=$(( deleted + 1 ))
        echo "    → BORRADO"
      fi
    else
      skipped=$(( skipped + 1 ))
    fi
  done < <(find "$OUTPUT_DIR" -type f -print0 2>/dev/null)

  echo ""
  echo "Resumen:"
  echo "  Candidatos:     $candidates"
  $APPLY && echo "  Borrados:       $deleted"
  echo "  Retenidos:      $skipped"
  $DRY_RUN && echo ""
  $DRY_RUN && echo "  (modo dry-run — ningún fichero borrado)"
fi
