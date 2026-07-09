#!/bin/bash
set -uo pipefail
# changelog-spec-field-check.sh — SE-258 Slice 4
# Verifica que entradas CHANGELOG.d tienen campo spec: y que el spec existe
# Modos: --check (exit 1 si falta), --warn (exit 0, solo aviso), default --check

MODE="${1:---check}"
if [[ "$MODE" != "--check" && "$MODE" != "--warn" ]]; then
  echo "Usage: $0 [--check|--warn]" >&2
  echo "  --check  exit 1 if issues found" >&2
  echo "  --warn   exit 0 but print issues" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG_DIR="$REPO_ROOT/CHANGELOG.d"
SPECS_DIR="$REPO_ROOT/docs/specs"
ARCHIVE_DIR="$REPO_ROOT/specs-archive"

if [[ ! -d "$CHANGELOG_DIR" ]]; then
  exit 0
fi

ISSUES=0
for entry in "$CHANGELOG_DIR"/*.md; do
  [[ ! -f "$entry" ]] && continue
  basename=$(basename "$entry" .md)

  spec_id=""
  if grep -q '^spec:' "$entry"; then
    spec_id=$(grep '^spec:' "$entry" | head -1 | sed 's/spec:[[:space:]]*//')
  fi

  if [[ -z "$spec_id" ]]; then
    spec_match=$(echo "$basename" | grep -oE 'se[0-9]+' || true)
    if [[ -n "$spec_match" ]]; then
      echo "ISSUE: $basename missing 'spec:' field in frontmatter"
      ISSUES=$((ISSUES + 1))
    fi
    continue
  fi

  found=0
  for pattern in "$SPECS_DIR/${spec_id}" "$SPECS_DIR/${spec_id^^}"; do
    if compgen -G "${pattern}*.md" > /dev/null 2>&1; then
      found=1
      break
    fi
  done
  if [[ "$found" -eq 0 ]] && [[ -d "$ARCHIVE_DIR" ]]; then
    if find "$ARCHIVE_DIR" -name "*${spec_id}*" -o -name "*${spec_id^^}*" 2>/dev/null | grep -q .; then
      found=1
    fi
  fi

  if [[ "$found" -eq 0 ]]; then
    echo "ISSUE: ${spec_id} referenced in CHANGELOG.d/$basename but spec file not found in docs/specs/ or specs-archive/"
    ISSUES=$((ISSUES + 1))
  fi
done

if [[ "$ISSUES" -eq 0 ]]; then
  echo "OK: all CHANGELOG.d entries have spec: field with existing spec files"
  exit 0
fi

echo ""
echo "Total issues: $ISSUES"
if [[ "$MODE" == "--warn" ]]; then
  echo "WARN: $ISSUES issue(s) found (non-blocking mode)"
  exit 0
fi

exit 1
