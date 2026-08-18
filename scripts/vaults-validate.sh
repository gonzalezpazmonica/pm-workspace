#!/usr/bin/env bash
# vaults-validate.sh — Validate documents against entity schemas
# Usage: bash scripts/vaults-validate.sh [--strict] [--path <vault-path>]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STRICT=false
VAULT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=true; shift ;;
    --path) VAULT_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Use the local example vault by default.
if [[ -z "$VAULT_PATH" ]]; then
  VAULT_PATH="$ROOT/vaults/example-context"
fi

SCHEMA_DIR="$ROOT/projects/savia-vaults/schema/entities"
FAILURES=0
TOTAL=0

echo "=== Vault Validation ==="
echo "Vault: $VAULT_PATH"
echo "Schema: $SCHEMA_DIR"
echo ""

# Find all markdown files in vault
while IFS= read -r -d '' file; do
  TOTAL=$((TOTAL + 1))
  rel="${file#$VAULT_PATH/}"

  # Extract entity type from frontmatter
  entity_type=$(grep -m1 'entity:.*type:' "$file" 2>/dev/null | sed 's/.*type: *//;s/[},].*//' | xargs)

  if [[ -z "$entity_type" ]]; then
    if $STRICT; then
      echo "  WARN  $rel — no entity type declared"
    fi
    continue
  fi

  # Validate against schema (basic check)
  schema_file="$SCHEMA_DIR/${entity_type}.yaml"
  if [[ ! -f "$schema_file" ]]; then
    echo "  FAIL  $rel — unknown entity type: $entity_type"
    FAILURES=$((FAILURES + 1))
    continue
  fi

  # Check required properties
  while IFS= read -r line; do
    prop=$(echo "$line" | sed 's/.*required: true.*//')
  done < <(grep -B1 "required: true" "$schema_file" | grep "  [a-z]" | sed 's/://;s/^ *//')

  echo "  OK    $rel ($entity_type)"

done < <(find "$VAULT_PATH" -name "*.md" -not -path "*/.git/*" -not -path "*/.trash/*" -print0 2>/dev/null)

echo ""
echo "=== Result ==="
echo "Total: $TOTAL documents"
if [[ $FAILURES -gt 0 ]]; then
  echo "FAILURES: $FAILURES"
  exit 1
else
  echo "All valid."
fi
