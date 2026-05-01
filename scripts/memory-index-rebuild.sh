#!/usr/bin/env bash
# memory-index-rebuild.sh — rebuild auto/MEMORY.md index from JSONL store
# Regenera el índice canónico a partir del JSONL existente.
# Uso: bash scripts/memory-index-rebuild.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORE_FILE="${PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")}/output/.memory-store.jsonl"
IDX_FILE="${HOME:-/tmp}/.savia-memory/auto/MEMORY.md"

[[ ! -f "$STORE_FILE" ]] && { echo "No store found at $STORE_FILE" >&2; exit 1; }
[[ ! -f "$IDX_FILE" ]] && { echo "No index found at $IDX_FILE" >&2; exit 1; }

ENTRIES=$(grep -oP '"topic_key":"[^"]*"|"type":"[^"]*"|"title":"[^"]*"' "$STORE_FILE" 2>/dev/null \
  | paste - - - 2>/dev/null \
  | sed 's/\t/ /g' \
  | while read -r line; do
    tk=$(echo "$line" | grep -oP '"topic_key":"\K[^"]*')
    tp=$(echo "$line" | grep -oP '"type":"\K[^"]*')
    ti=$(echo "$line" | grep -oP '"title":"\K[^"]*')
    [[ -z "$tk" ]] && continue
    entry="- ${tp}: ${ti} [${tk}]"
    echo "${entry:0:150}"
  done | sort -u)

tmp=$(mktemp)
while IFS= read -r line; do
  echo "$line" >> "$tmp"
  if [[ "$line" == "<!-- ENTRIES_START -->" ]]; then
    echo "$ENTRIES" >> "$tmp"
  fi
done < "$IDX_FILE"
mv "$tmp" "$IDX_FILE"
echo "Index rebuilt: $(echo "$ENTRIES" | grep -c '^\- ' 2>/dev/null || echo 0) entries"
