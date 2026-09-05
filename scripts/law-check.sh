#!/usr/bin/env bash
# law-check.sh — SE-386 S1: valida Law Registry.
# Cada LAW del index debe existir (id + MUST/MUST NOT) en su documento.
set -uo pipefail
ROOT="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
LAWS="$ROOT/laws"
FAILS=0
while IFS= read -r id; do
  doc=$(grep -A6 "^  - id: $id\$" "$LAWS/index.yaml" | grep -oP 'document:\s*\K.+\.md' | head -1)
  f="$LAWS/${doc:-missing.md}"
  if [[ ! -f "$f" ]] || ! grep -qE "^## $id( |$)" "$f"; then
    echo "FAIL: LAW $id sin seccion en $doc"; FAILS=$((FAILS+1)); continue
  fi
    grep -qE " MUST( NOT)? " "$f" || { echo "FAIL: LAW $id sin MUST/MUST NOT"; FAILS=$((FAILS+1)); }
done < <(grep -oP '^\s*-\s+id:\s*\KLAW-[A-Z]+-[0-9]+' "$LAWS/index.yaml")
if [[ $FAILS -eq 0 ]]; then echo "PASS: $(grep -cP '^\s*- id:' "$LAWS/index.yaml") leyes en registry"; exit 0; fi
echo "-- law-check: $FAILS fallo(s)"; exit 1
