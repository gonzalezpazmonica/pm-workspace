#!/usr/bin/env bash
set -uo pipefail
# config-snapshot.sh — SE-405 Slice 2: copias previas de ficheros de configuración.
#
#   snapshot <file>              copia el contenido actual
#   list [<file>]                lista snapshots (id, fecha, tamaño), más reciente primero
#   restore <id> --confirm       restaura; antes guarda snapshot del estado sustituido
#
# Destino: ${SAVIA_CONFIG_SNAPSHOT_DIR:-$HOME/.savia/config-snapshots}/<basename>/<UTC>-<sha8>
# Un id es "<basename>/<UTC>-<sha8>". Retención: 30 por fichero. La ruta original
# se guarda en "<id>.path" para poder restaurar.
# Ref: docs/specs/SE-405-harness-observability-increments.spec.md

DIR="${SAVIA_CONFIG_SNAPSHOT_DIR:-$HOME/.savia/config-snapshots}"
KEEP="${SAVIA_CONFIG_SNAPSHOT_KEEP:-30}"

usage() { echo "Usage: $0 {snapshot <file> | list [<file>] | restore <id> --confirm}" >&2; exit 2; }

do_snapshot() {
  local file="${1:-}"
  [[ -f "$file" ]] || { echo "ERROR: no existe: $file" >&2; return 1; }
  local abs; abs=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")
  local base; base=$(basename "$abs")
  local sha; sha=$(sha256sum "$abs" | cut -c1-8)
  local ts; ts=$(date -u +%Y%m%dT%H%M%S%N | cut -c1-21)
  mkdir -p "$DIR/$base" || return 1
  cp -p "$abs" "$DIR/$base/$ts-$sha"
  printf '%s\n' "$abs" > "$DIR/$base/$ts-$sha.path"
  # Retención: conservar los KEEP más recientes (los nombres ordenan por fecha).
  local old
  old=$(find "$DIR/$base" -maxdepth 1 -type f ! -name '*.path' -printf '%f\n' | sort -r | tail -n +$((KEEP + 1)))
  local f
  for f in $old; do
    find "$DIR/$base" -maxdepth 1 \( -name "$f" -o -name "$f.path" \) -delete
  done
  echo "$base/$ts-$sha"
}

do_list() {
  local filter=""
  [[ -n "${1:-}" ]] && filter=$(basename "$1")
  [[ -d "$DIR" ]] || return 0
  find "$DIR" -mindepth 2 -maxdepth 2 -type f ! -name '*.path' -printf '%P\t%s\n' \
    | { [[ -n "$filter" ]] && grep "^$filter/" || cat; } | sort -r \
    | awk -F'\t' '{print $1"\t"$2" bytes"}'
}

do_restore() {
  local id="${1:-}" confirm="${2:-}"
  [[ -z "$id" ]] && usage
  [[ "$confirm" == "--confirm" ]] || { echo "ERROR: restore exige --confirm (sin cambios)" >&2; return 2; }
  local snap="$DIR/$id"
  [[ -f "$snap" && -f "$snap.path" ]] || { echo "ERROR: snapshot desconocido: $id" >&2; return 1; }
  local target; target=$(cat "$snap.path")
  [[ -f "$target" ]] && do_snapshot "$target" >/dev/null
  cp -p "$snap" "$target"
  echo "Restaurado $target desde $id"
}

case "${1:-}" in
  snapshot) shift; do_snapshot "$@" ;;
  list) shift; do_list "$@" ;;
  restore) shift; do_restore "$@" ;;
  *) usage ;;
esac
