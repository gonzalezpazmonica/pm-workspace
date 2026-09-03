#!/usr/bin/env bash
# cache-hygiene.sh — SE-371: disciplina de prefijo para prompt caching.
#
# El prompt cache del provider es prefijo-exacto: un byte distinto en el
# prefijo de instrucciones invalida el cache desde ese punto. Este script
# hace visible esa mutación:
#
#   snapshot [--out FILE]   guarda sha256 de cada fichero del manifest
#   check    [--out FILE]   detecta qué fichero mutó desde el snapshot
#   --validate              manifest coherente (paths existen) y MEMORY.md fuera
#
# Manifest: config/cache-prefix.txt (orden canónico del prefijo).
# CRIT-001: 100% local, sin red, determinista.
#
# Exit: snapshot/check 0 ok · 1 mutación o incoherencia · 2 uso/error.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="${CACHE_PREFIX_MANIFEST:-$REPO_ROOT/config/cache-prefix.txt}"
DEFAULT_SNAPSHOT="$REPO_ROOT/data/cache-prefix.snapshot"

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

# sha256 con conteo de lineas: estable pese a mtime. "sha256sum <path>" | cut.
file_hash() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

manifest_paths() {
  # devuelve solo paths, ignorando comentarios y vacios
  grep -vE '^\s*#|^\s*$' "$MANIFEST" 2>/dev/null
}

cmd_snapshot() {
  local out="$DEFAULT_SNAPSHOT"
  [[ "${1:-}" == "--out" ]] && { out="$2"; shift 2; }
  [[ -f "$MANIFEST" ]] || { echo "ERROR: manifest no encontrado: $MANIFEST" >&2; exit 2; }
  local dir; dir="$(dirname "$out")"; mkdir -p "$dir"
  {
    echo "# cache-prefix snapshot — SE-371 ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
    echo "# manifest: $(file_hash "$MANIFEST")"
    local p
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      if [[ -f "$REPO_ROOT/$p" ]]; then
        echo "$p $(file_hash "$REPO_ROOT/$p")"
      else
        echo "$p MISSING"
      fi
    done < <(manifest_paths)
  } > "$out"
  echo "snapshot: $out ($(grep -cE '^[^#]' "$out") ficheros)"
}

cmd_check() {
  local out="$DEFAULT_SNAPSHOT"
  [[ "${1:-}" == "--out" ]] && { out="$2"; shift 2; }
  [[ -f "$out" ]] || { echo "ERROR: no hay snapshot: $out — ejecuta snapshot primero" >&2; exit 2; }
  local mutated=0 p cur snap
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    cur="$(file_hash "$REPO_ROOT/$p")"
    snap="$(grep -E "^$(printf '%s' "$p" | sed 's/[.[\*^$()+?{|]/\\&/g') " "$out" | head -1 | cut -d' ' -f2)"
    if [[ "$snap" == "MISSING" || -z "$snap" ]]; then
      echo "MUTATED $p (sin snapshot previo o fichero nuevo)"
      mutated=1
    elif [[ "$cur" != "$snap" ]]; then
      echo "MUTATED $p"
      mutated=1
    fi
  done < <(manifest_paths)
  if [[ "$mutated" -eq 0 ]]; then
    echo "check: prefijo estable (0 ficheros mutados)"
    return 0
  fi
  echo "check: PREFIJO MUTADO — el prompt cache se invalidó en el siguiente turno" >&2
  return 1
}

cmd_validate() {
  local fail=0 p
  [[ -f "$MANIFEST" ]] || { echo "ERROR: manifest no encontrado: $MANIFEST" >&2; exit 2; }
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    if [[ ! -f "$REPO_ROOT/$p" ]]; then
      echo "FAIL path inexistente en manifest: $p"
      fail=1
    fi
  done < <(manifest_paths)
  # AC-4: MEMORY.md fuera del prefijo
  if grep -q 'external-memory/auto/MEMORY.md' "$REPO_ROOT/config/cache-prefix.txt"; then
    echo "FAIL MEMORY.md no debe estar en el prefijo (SE-371 AC-4)"
    fail=1
  fi
  if grep -q 'MEMORY.md' "$REPO_ROOT/opencode.json"; then
    echo "FAIL MEMORY.md no debe estar en instructions de opencode.json (SE-371 AC-4)"
    fail=1
  fi
  # MEMORY.md solo puede aparecer como comentario de documentacion
  if grep -q 'external-memory/auto/MEMORY.md' "$REPO_ROOT/CLAUDE.md"; then
    # CLAUDE.md lo referencia bajo el bloque lazy (linea "Usuario activo"): la
    # referencia en tabla lazy es un @import critico -> avisar, no fallar.
    echo "WARN MEMORY.md referenciado en CLAUDE.md (revisar que sea lazy, no @import)"
  fi
  [[ "$fail" -eq 0 ]] && { echo "validate: OK (manifest coherente, MEMORY.md fuera del prefijo)"; return 0; }
  return 1
}

case "${1:-}" in
  snapshot) shift; cmd_snapshot "$@" ;;
  check)    shift; cmd_check "$@" ;;
  --validate|validate) cmd_validate ;;
  -h|--help) usage ;;
  *) usage ;;
esac
exit $?
