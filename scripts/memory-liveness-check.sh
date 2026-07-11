#!/usr/bin/env bash
# scripts/memory-liveness-check.sh — SE-257 Slice 2
# Verifica que todos los scripts de memoria tienen consumidor vivo
# y que no hay huerfanos.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

CHECK_MISSING=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-missing)
      CHECK_MISSING=true
      shift
      if [[ -z "${1:-}" ]]; then
        echo "ERROR: --check-missing requires a path argument" >&2
        exit 1
      fi
      if [[ ! -e "$1" ]]; then
        echo "ERROR: artifact not found: $1" >&2
        exit 1
      fi
      echo "  OK: artifact exists: $1"
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

echo "=== Memory Liveness Check ==="

MEMORY_SCRIPTS=$(find "$ROOT/scripts" \( -name "*memory*" -o -name "*memor*" -o -name "*bitemporal*" \) ! -name "*.pyc" ! -name "test-*" | grep -v "_legacy" | sort)
ORPHANS=0
OK=0

check_referenced() {
  local script="$1"
  local name=$(basename "$script")
  # Buscar referencias al script en todo el repo
  if grep -rq "$name" "$ROOT/scripts/" "$ROOT/docs/" "$ROOT/.claude/" "$ROOT/.opencode/" "$ROOT/tests/" 2>/dev/null; then
    echo "  OK: $name"
    OK=$((OK + 1))
  else
    echo "  ORPHAN: $name (no references found)"
    ORPHANS=$((ORPHANS + 1))
  fi
}

for s in $MEMORY_SCRIPTS; do
  check_referenced "$s"
done

echo ""
echo "  Total: $OK OK, $ORPHANS orphans"
[ "$ORPHANS" -gt 0 ] && exit 1
exit 0
