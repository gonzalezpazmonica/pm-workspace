#!/bin/bash
set -uo pipefail
# verify-ledger-chain.sh — SE-258 Slice 2
# Verifica la cadena de hashes SHA256 del libro de la relacion

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEDGER="${LEDGER:-$REPO_ROOT/data/relacion/ledger.jsonl}"

if [[ ! -f "$LEDGER" ]]; then
  echo "ledger.jsonl not found — expected after destracking (SE-258 S1)"
  exit 0
fi

echo "=== Ledger Chain Verification ==="

LINE_NUM=0
PREV_LINE=""
CHAIN_OK=0
CHAIN_BROKEN=0

while IFS= read -r line; do
  LINE_NUM=$((LINE_NUM + 1))
  [[ -z "$line" ]] && continue

  if ! echo "$line" | jq empty 2>/dev/null; then
    echo "  [$LINE_NUM] INVALID: not valid JSON"
    CHAIN_BROKEN=$((CHAIN_BROKEN + 1))
    continue
  fi

  hash_prev=$(echo "$line" | jq -r '.hash_prev // empty' 2>/dev/null)
  entry_id=$(echo "$line" | jq -r '.entry_id // "?"' 2>/dev/null)

  if [ "$LINE_NUM" -eq 1 ]; then
    if [ "$hash_prev" = "null" ] || [ -z "$hash_prev" ]; then
      echo "  [$LINE_NUM] SEED: $entry_id (root, no parent)"
      CHAIN_OK=$((CHAIN_OK + 1))
    else
      echo "  [$LINE_NUM] ERROR: first entry should have hash_prev=null, got '$hash_prev'"
      CHAIN_BROKEN=$((CHAIN_BROKEN + 1))
    fi
  else
    computed_hash=$(echo "$PREV_LINE" | sha256sum | cut -d' ' -f1)
    if [ "$computed_hash" = "$hash_prev" ]; then
      echo "  [$LINE_NUM] OK: $entry_id (hash matches)"
      CHAIN_OK=$((CHAIN_OK + 1))
    else
      echo "  [$LINE_NUM] BROKEN: $entry_id"
      echo "    Expected: $computed_hash"
      echo "    Got:      $hash_prev"
      CHAIN_BROKEN=$((CHAIN_BROKEN + 1))
    fi
  fi

  PREV_LINE="$line"
done < "$LEDGER"

echo ""
echo "=== Result ==="
echo "Valid links: $CHAIN_OK"
echo "Broken links: $CHAIN_BROKEN"

if [ "$CHAIN_BROKEN" -gt 0 ]; then
  echo "CHAIN BROKEN: $CHAIN_BROKEN link(s) invalid."
  exit 1
fi

echo "Chain integrity: OK"
exit 0
