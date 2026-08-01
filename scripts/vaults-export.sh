#!/usr/bin/env bash
# vaults-export.sh — Export vault with confidentiality filtering and signing
# Usage: bash scripts/vaults-export.sh --vault <name> --output <dir> [--max-level N2]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT/config/vaults.yaml"
VAULT_NAME=""
OUTPUT_DIR=""
MAX_LEVEL="N2"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_NAME="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --max-level) MAX_LEVEL="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$VAULT_NAME" || -z "$OUTPUT_DIR" ]]; then
  echo "Usage: $0 --vault <name> --output <dir> [--max-level N2]"
  exit 1
fi

VAULT_PATH=$(grep -A5 "^  ${VAULT_NAME}:" "$CONFIG_FILE" 2>/dev/null | grep "path:" | head -1 | sed 's/.*path: *//;s/"//g' | xargs)
[[ -n "$VAULT_PATH" ]] && VAULT_PATH="$ROOT/$VAULT_PATH"

CONFIGURED_LEVEL=$(grep -A5 "^  ${VAULT_NAME}:" "$CONFIG_FILE" | grep "max_confidentiality:" | head -1 | sed 's/.*max_confidentiality: *//' | xargs)

if [[ -z "$VAULT_PATH" ]]; then
  echo "ERROR: Unknown vault: $VAULT_NAME"
  exit 1
fi

echo "=== Vault Export ==="
echo "Vault: $VAULT_NAME ($VAULT_PATH)"
echo "Max level: $MAX_LEVEL"
echo "Configured level: ${CONFIGURED_LEVEL:-N2}"
echo "Output: $OUTPUT_DIR"
echo ""

mkdir -p "$OUTPUT_DIR"

# Level hierarchy for filtering
level_rank() {
  case "$1" in
    N1) echo 1 ;; N2) echo 2 ;; N3) echo 3 ;; N4) echo 4 ;; N4b) echo 5 ;;
    *) echo 2 ;;
  esac
}

MAX_RANK=$(level_rank "$MAX_LEVEL")
EXPORTED=0
FILTERED=0

# Copy structure
cp "$VAULT_PATH/INDEX.md" "$OUTPUT_DIR/" 2>/dev/null || true
cp "$VAULT_PATH/MAP.md" "$OUTPUT_DIR/" 2>/dev/null || true

# Export documents with level filtering
while IFS= read -r -d '' file; do
  rel="${file#$VAULT_PATH/}"
  dest="$OUTPUT_DIR/$rel"
  mkdir -p "$(dirname "$dest")"

  # Check confidentiality level in frontmatter
  doc_level=$(grep -m1 "confidentiality:" "$file" 2>/dev/null | sed 's/.*confidentiality: *//;s/[",}].*//' | xargs || echo "N2")
  doc_rank=$(level_rank "${doc_level:-N2}")

  if [[ "$doc_rank" -le "$MAX_RANK" ]]; then
    cp "$file" "$dest"
    EXPORTED=$((EXPORTED + 1))
  else
    FILTERED=$((FILTERED + 1))
    echo "  FILTERED $rel (level $doc_level > $MAX_LEVEL)"
  fi
done < <(find "$VAULT_PATH" -name "*.md" -not -path "*/.git/*" -not -name "INDEX.md" -not -name "MAP.md" -print0 2>/dev/null)

# Generate manifest
cat > "$OUTPUT_DIR/.vault-manifest.yaml" << MANIFEST
source_vault: $VAULT_NAME
source_instance: $(hostname 2>/dev/null || echo "unknown")
exported_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
max_level: $MAX_LEVEL
documents_exported: $EXPORTED
documents_filtered: $FILTERED
MANIFEST

echo ""
echo "=== Export Complete ==="
echo "Exported: $EXPORTED documents"
echo "Filtered: $FILTERED (above level $MAX_LEVEL)"
echo "Manifest: $OUTPUT_DIR/.vault-manifest.yaml"
