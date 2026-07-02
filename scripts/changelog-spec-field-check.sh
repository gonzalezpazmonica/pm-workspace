#!/usr/bin/env bash
set -euo pipefail
# Verifica que entradas CHANGELOG.d con feat(seNNN) tienen campo spec: SE-NNN
# Modo: --check (exit 1 si falta), --warn (solo aviso)
# Uso en CI: bash scripts/changelog-spec-field-check.sh --check

MODE="${1:---warn}"

if [[ "$MODE" != "--check" && "$MODE" != "--warn" ]]; then
  echo "Usage: $0 [--check|--warn]" >&2
  echo "  --check  exit 1 if any CHANGELOG.d entry is missing spec: field" >&2
  echo "  --warn   exit 0 but print list of missing entries" >&2
  exit 2
fi

CHANGELOG_DIR="${CHANGELOG_DIR:-CHANGELOG.d}"

if [[ ! -d "$CHANGELOG_DIR" ]]; then
  echo "ERROR: $CHANGELOG_DIR not found (run from repo root)" >&2
  exit 2
fi

MISSING=()

while IFS= read -r -d '' f; do
  filename=$(basename "$f")

  # Check if title line matches feat(seNNN) or fix(seNNN) pattern
  # Look in first 5 lines for a markdown h1 with that pattern
  title_line=$(head -10 "$f" | grep -iE "^#\s+feat\(se|^#\s+fix\(se" | head -1 || true)

  if [[ -z "$title_line" ]]; then
    # No matching title - skip
    continue
  fi

  # Has a feat(se/fix(se title - now check for spec: field
  # Either in YAML frontmatter or anywhere in body
  if grep -qiE "^spec:\s+SE-[0-9]+" "$f" 2>/dev/null; then
    # Has spec: field - OK
    continue
  fi

  MISSING+=("$filename")
done < <(find "$CHANGELOG_DIR" -maxdepth 1 -name "*.md" -print0 | sort -z)

if [[ ${#MISSING[@]} -eq 0 ]]; then
  echo "OK: all feat(seNNN)/fix(seNNN) CHANGELOG.d entries have spec: field"
  exit 0
fi

echo "WARN: ${#MISSING[@]} CHANGELOG.d entry/entries missing spec: field:"
for f in "${MISSING[@]}"; do
  echo "  - $f"
done

if [[ "$MODE" == "--check" ]]; then
  exit 1
fi

exit 0
