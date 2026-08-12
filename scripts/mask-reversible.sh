#!/usr/bin/env bash
# mask-reversible.sh — SE-323 S1: reversible identifier masking for RCA.
#
# Wrapper de mask-reversible.py. Detecta IDs (pods, clusters, account IDs,
# IPs, servicios, imágenes) y los sustituye por placeholders únicos
# ({POD_1}, {IP_2}...). El mapa placeholder<->valor se guarda en un fichero
# efímero (N4b, no persistido) y --restore recompone el output original.
#
# Uso:
#   cat file.txt | mask-reversible.sh mask --map <ephemeral-map>
#   cat masked.txt | mask-reversible.sh restore --map <ephemeral-map>
#   cat file.txt | mask-reversible.sh dry-run --map <ephemeral-map>
#
# Exit: 0 ok (incluye passthrough sin IDs), 1 map error, 2 uso inválido.
# Ref: SE-323.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$SCRIPT_DIR/mask-reversible.py"

ACTION="${1:-}"
[[ -z "$ACTION" ]] && { echo "usage: mask-reversible.sh {mask|restore|dry-run} --map <file>" >&2; exit 2; }
shift

MAP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --map) MAP="$2"; shift 2 ;;
    *) echo "ERROR: argumento desconocido '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$MAP" ]] && { echo "ERROR: falta --map <file>" >&2; exit 2; }

case "$ACTION" in
  mask|restore|dry-run)
    if [[ ! -t 0 ]]; then
      python3 "$PY" "$ACTION" --map "$MAP"
    else
      echo "ERROR: no input. Pipe text via stdin." >&2
      exit 2
    fi
    ;;
  *)
    echo "usage: mask-reversible.sh {mask|restore|dry-run} --map <file>" >&2
    exit 2
    ;;
esac
