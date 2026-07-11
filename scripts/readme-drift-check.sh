#!/usr/bin/env bash
set -euo pipefail

SOURCE_FILE="README.md"
LANGUAGES="ca gl eu it en"
SOURCE_SECTIONS=$(grep -c '^## ' "$SOURCE_FILE")
HAS_DRIFT=0

for lang in $LANGUAGES; do
  TRANSLATION="README.${lang}.md"
  if [[ ! -f "$TRANSLATION" ]]; then
    echo "WARNING: $TRANSLATION not found"
    HAS_DRIFT=1
    continue
  fi

  TR_SECTIONS=$(grep -c '^## ' "$TRANSLATION")
  if [[ "$TR_SECTIONS" -ne "$SOURCE_SECTIONS" ]]; then
    echo "WARNING: $TRANSLATION has $TR_SECTIONS H2 sections (source has $SOURCE_SECTIONS)"
    HAS_DRIFT=1
  fi
done

if [[ "$HAS_DRIFT" -eq 0 ]]; then
  echo "OK: all README translations in sync ($SOURCE_SECTIONS H2 sections)"
fi

exit $HAS_DRIFT
