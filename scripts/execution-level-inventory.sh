#!/usr/bin/env bash
set -euo pipefail
# execution-level-inventory.sh — Full inventory of scripts/hooks with execution levels
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

format="${1:-text}"

n_anfitrion=0; n_contenido=0; n_hostil=0; n_unclassified=0
results=""

cd "$ROOT"

while IFS= read -r -d '' f; do
  rel="${f#$ROOT/}"
  level_out=$("$SCRIPT_DIR/classify-execution-level.sh" "$f" 2>/dev/null || echo "UNCLASSIFIED: $rel")
  level=$(echo "$level_out" | cut -d: -f1 | tr -d ' ')
  reason=$(echo "$level_out" | cut -d: -f2- | sed 's/^ //')

  case "$level" in
    N-anfitrion) n_anfitrion=$((n_anfitrion + 1)) ;;
    N-contenido) n_contenido=$((n_contenido + 1)) ;;
    N-hostil)    n_hostil=$((n_hostil + 1)) ;;
    *)           n_unclassified=$((n_unclassified + 1)) ;;
  esac

  results+="$level|$rel|$reason"$'\n'
done < <(find "$ROOT" -type f \( -name '*.sh' -o -name '*.bash' \) -not -path '*/node_modules/*' -not -path '*/.git/*' -print0 2>/dev/null)

if [[ "$format" == "--json" ]]; then
  echo '['
  first=true
  while IFS='|' read -r level path reason; do
    [[ -z "$level" ]] && continue
    $first || echo ','
    first=false
    echo -n "  {\"path\": \"$path\", \"level\": \"$level\", \"reason\": \"$reason\"}"
  done <<< "$results"
  echo ''
  echo ']'
else
  echo "Execution Level Inventory"
  echo "========================="
  printf "%-14s %s\n" "LEVEL" "SCRIPT"
  echo "----------------------------------------"
  while IFS='|' read -r level path reason; do
    [[ -z "$level" ]] && continue
    printf "%-14s %s\n" "$level" "$path"
  done <<< "$results"
  echo "----------------------------------------"
  echo "N-anfitrion: $n_anfitrion | N-contenido: $n_contenido | N-hostil: $n_hostil | UNCLASSIFIED: $n_unclassified"
fi

[[ $n_unclassified -gt 0 ]] && exit 1
exit 0
