#!/usr/bin/env bash
# validate-pbi-spec-links.sh — Check bidirectional PBI ↔ Spec links
# Scans PBI files for specs: entries and spec files for parent_pbi: entries.
# Reports broken links as warnings (work in progress is OK).
set -euo pipefail

PROJECT_DIR="${1:-projects/savia-web}"
PBI_DIR="$PROJECT_DIR/backlog/pbi"
SPECS_DIR="$PROJECT_DIR/specs"

warnings=0
checked_pbis=0
checked_specs=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PBI ↔ Spec Link Validator"
echo "  Project: $PROJECT_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# --- Phase 1: Check PBI specs: entries point to existing spec files ---
echo "Phase 1: Checking PBI → Spec links..."

if [ -d "$PBI_DIR" ]; then
  for pbi_file in "$PBI_DIR"/PBI-*.md; do
    [ -f "$pbi_file" ] || continue
    checked_pbis=$((checked_pbis + 1))
    pbi_id=$(basename "$pbi_file" .md | sed 's/-.*//' | head -1)

    # Extract spec paths from specs: array entries (format: - path: "...")
    while IFS= read -r spec_path; do
      [ -z "$spec_path" ] && continue
      # Resolve path relative to project dir
      full_path="$PROJECT_DIR/$spec_path"
      if [ ! -f "$full_path" ]; then
        echo "  WARNING: $pbi_id references spec '$spec_path' but file not found"
        warnings=$((warnings + 1))
      fi
    done < <(grep -A1 '^\s*- path:' "$pbi_file" 2>/dev/null \
      | grep 'path:' | sed 's/.*path:\s*"\?\([^"]*\)"\?.*/\1/' || true)
  done
fi

echo "  Checked $checked_pbis PBI files"
echo ""

# --- Phase 2: Check Spec parent_pbi: entries point to existing PBI files ---
echo "Phase 2: Checking Spec → PBI links..."

if [ -d "$SPECS_DIR" ]; then
  for spec_file in "$SPECS_DIR"/*.spec.md; do
    [ -f "$spec_file" ] || continue
    checked_specs=$((checked_specs + 1))
    spec_name=$(basename "$spec_file")

    # Extract parent_pbi from Metadatos section only (not from code blocks)
    # Read lines between "## Metadatos" and next "##" heading
    parent_pbi=$(sed -n '/^## Metadatos/,/^## [^M]/p' "$spec_file" 2>/dev/null \
      | grep -m1 '^- parent_pbi:' \
      | sed 's/^- parent_pbi:\s*//' \
      | sed 's/\s*#.*//' \
      | sed 's/^"\(.*\)"$/\1/' \
      | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || true)

    # Skip if no parent_pbi field or empty value
    [ -z "$parent_pbi" ] && continue

    # Check if PBI file exists (search by ID prefix)
    found=0
    for candidate in "$PBI_DIR"/${parent_pbi}-*.md "$PBI_DIR"/${parent_pbi}.md; do
      if [ -f "$candidate" ]; then
        found=1
        break
      fi
    done

    if [ "$found" -eq 0 ]; then
      echo "  WARNING: $spec_name has parent_pbi '$parent_pbi' but PBI file not found"
      warnings=$((warnings + 1))
    fi
  done
fi

echo "  Checked $checked_specs spec files"
echo ""

# --- Summary ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$warnings" -eq 0 ]; then
  echo "  Result: OK — No broken links found"
else
  echo "  Result: $warnings warning(s) — broken links detected"
fi
echo "  PBIs scanned: $checked_pbis"
echo "  Specs scanned: $checked_specs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
