#!/usr/bin/env bash
# glm-compute-digest.sh — Computes SHA-256 of governance-layer-manifest.json
# and replaces the manifest_digest.value field in-place.
#
# Usage: bash scripts/glm-compute-digest.sh [--dry-run]
# Exit codes: 0=success, 1=error

set -uo pipefail

MANIFEST=".well-known/governance-layer-manifest.json"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: $MANIFEST not found. Run from repo root." >&2
  exit 1
fi

# Create a canonicalized version with <computed> placeholder stripped for hashing
TMP=$(mktemp /tmp/glm-digest.XXXXXX)
trap 'rm -f "$TMP"' EXIT

# Replace current digest value with placeholder before computing
sed 's/"value": "[^"]*"/"value": "<computed>"/' "$MANIFEST" > "$TMP"

DIGEST=$(sha256sum "$TMP" | awk '{print $1}')

if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY-RUN: digest would be sha256:${DIGEST}"
  exit 0
fi

# Replace in-place: sed works on the actual manifest
sed -i "s/\"value\": \"<computed>\"/\"value\": \"${DIGEST}\"/" "$MANIFEST"
sed -i "s/\"value\": \"[a-f0-9]\{64\}\"/\"value\": \"${DIGEST}\"/" "$MANIFEST"

echo "PASS: manifest_digest updated → sha256:${DIGEST}"
