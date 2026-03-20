#!/bin/bash
# sync-tags-from-changelog.sh — Create missing git tags from CHANGELOG.md
# Usage: bash scripts/sync-tags-from-changelog.sh [--dry-run] [--push]
#
# Reads CHANGELOG.md headings, finds the merge commit closest to each
# version date, and creates lightweight tags for missing versions.

set -euo pipefail

DRY_RUN=false
PUSH=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --push)    PUSH=true ;;
  esac
done

CHANGELOG="CHANGELOG.md"
if [ ! -f "$CHANGELOG" ]; then
  echo "ERR: $CHANGELOG not found" >&2
  exit 1
fi

created=0
skipped=0
failed=0

# Parse CHANGELOG: extract version and date pairs
grep -oP '^\#\# \[\K[0-9]+\.[0-9]+\.[0-9]+\] — \K[0-9-]+' "$CHANGELOG" \
  | paste -d'|' <(grep -oP '^\#\# \[\K[0-9]+\.[0-9]+\.[0-9]+' "$CHANGELOG") - \
  | while IFS='|' read -r ver date; do
  tag="v$ver"

  # Skip if tag already exists
  if git tag -l "$tag" | grep -q .; then
    skipped=$((skipped + 1))
    continue
  fi

  # Find the best commit for this version date
  # Strategy: last commit on or before the date
  commit=$(git log --until="$date 23:59:59" --format="%H" -1 2>/dev/null || true)

  if [ -z "$commit" ]; then
    echo "SKIP $tag — no commit found for date $date"
    failed=$((failed + 1))
    continue
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "DRY-RUN: would tag $tag at $commit ($date)"
  else
    if git tag "$tag" "$commit" 2>/dev/null; then
      echo "CREATED: $tag -> $(echo "$commit" | cut -c1-7) ($date)"
      created=$((created + 1))
    else
      echo "FAILED: $tag"
      failed=$((failed + 1))
    fi
  fi
done

echo ""
echo "Done. Created: $created | Skipped (exist): $skipped | Failed: $failed"

if [ "$PUSH" = true ] && [ "$DRY_RUN" = false ]; then
  echo "Pushing tags to origin..."
  git push origin --tags 2>&1
fi
