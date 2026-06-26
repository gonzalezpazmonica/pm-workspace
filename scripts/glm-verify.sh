#!/usr/bin/env bash
# glm-verify.sh — Verifies that manifest_digest.value matches computed SHA-256
#
# Usage: bash scripts/glm-verify.sh
# Exit codes: 0=PASS, 1=FAIL

set -uo pipefail

MANIFEST=".well-known/governance-layer-manifest.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "FAIL: $MANIFEST not found. Run from repo root." >&2
  exit 1
fi

# Extract stored digest
STORED=$(python3 -c "
import json, sys
data = json.load(open('$MANIFEST'))
print(data.get('manifest_digest', {}).get('value', ''))
" 2>/dev/null || grep -o '"value": "[^"]*"' "$MANIFEST" | tail -1 | sed 's/"value": "\(.*\)"/\1/')

if [[ -z "$STORED" || "$STORED" == "<computed>" ]]; then
  echo "FAIL: manifest_digest.value is missing or placeholder. Run scripts/glm-compute-digest.sh first." >&2
  exit 1
fi

# Compute digest with placeholder in place of stored value
TMP=$(mktemp /tmp/glm-verify.XXXXXX)
trap 'rm -f "$TMP"' EXIT

sed "s/\"value\": \"${STORED}\"/\"value\": \"<computed>\"/" "$MANIFEST" > "$TMP"
COMPUTED=$(sha256sum "$TMP" | awk '{print $1}')

if [[ "$STORED" == "$COMPUTED" ]]; then
  echo "PASS: manifest digest verified sha256:${COMPUTED}"
  exit 0
else
  echo "FAIL: digest mismatch"
  echo "  stored:   sha256:${STORED}"
  echo "  computed: sha256:${COMPUTED}"
  echo "  Run: bash scripts/glm-compute-digest.sh"
  exit 1
fi
