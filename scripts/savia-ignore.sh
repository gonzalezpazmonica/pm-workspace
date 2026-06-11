#!/usr/bin/env bash
# savia-ignore.sh — SE-218 S5: tool-specific exclusion layer
# Ref: docs/propuestas/SE-218-codebase-memory-patterns.md
# Usage: bash scripts/savia-ignore.sh <path>
# Exit: 0 = ignorado, 1 = no ignorado
set -uo pipefail

WORKSPACE_ROOT="${SAVIA_WORKSPACE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
IGNORE_FILE="$WORKSPACE_ROOT/.saviaignore"
TARGET="${1:-}"

[[ -z "$TARGET" ]] && echo "Usage: savia-ignore.sh <path>" >&2 && exit 2
[[ ! -f "$IGNORE_FILE" ]] && exit 1  # sin .saviaignore: nada ignorado

# Usar git check-ignore si está disponible (respeta sintaxis gitignore completa)
if command -v git >/dev/null 2>&1; then
  if git -C "$WORKSPACE_ROOT" check-ignore -q --no-index \
       --stdin <<< "$TARGET" 2>/dev/null; then
    exit 0
  fi
  # Fallback: usar el fichero directamente
  if git check-ignore -q --no-index \
       --stdin <<< "$TARGET" \
       --input "$IGNORE_FILE" 2>/dev/null; then
    exit 0
  fi
fi

# Fallback manual: matching simple de patrones
while IFS= read -r pattern; do
  [[ -z "$pattern" || "$pattern" == \#* ]] && continue
  # Negación
  if [[ "$pattern" == \!* ]]; then
    stripped="${pattern#!}"
    [[ "$TARGET" == $stripped || "$TARGET" == */"$stripped" ]] && exit 1
    continue
  fi
  # Match directo o glob
  [[ "$TARGET" == $pattern || "$TARGET" == */"$pattern" || "$TARGET" == "$pattern"/* ]] && exit 0
done < "$IGNORE_FILE"

exit 1
