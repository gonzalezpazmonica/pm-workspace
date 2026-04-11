#!/usr/bin/env bash
# release-backfill.sh — Create missing GitHub releases from git tags
#
# Background: for a long time, auto-tag.yml pushed tags via GITHUB_TOKEN
# but the tag push did not trigger release.yml (GitHub safeguard: tokens
# cannot trigger other workflows). Result: ~170 git tags exist with no
# corresponding GitHub release.
#
# This script finds missing releases and creates them one by one using
# the changelog entry extracted from CHANGELOG.md.
#
# Usage: bash scripts/release-backfill.sh [options]
#
# Options:
#   --dry-run          Show what would be created, do not create
#   --limit N          Only process first N missing releases (default: all)
#   --from VERSION     Start from this version (e.g., 4.0.0)
#   --to VERSION       Stop at this version (inclusive)
#   --force            Overwrite existing releases (dangerous)
#   --help             Show this help
#
# Prerequisites:
#   - gh CLI authenticated (gh auth status)
#   - git fetch --tags done
#   - Run from repo root

set -uo pipefail

DRY_RUN=false
LIMIT=0
FROM_VERSION=""
TO_VERSION=""
FORCE=false

show_help() {
  sed -n '2,22p' "$0" | sed 's/^# \?//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --from) FROM_VERSION="$2"; shift 2 ;;
    --to) TO_VERSION="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    --help|-h) show_help; exit 0 ;;
    *) echo "Error: unknown option $1" >&2; exit 2 ;;
  esac
done

# Verify prerequisites
command -v gh >/dev/null || { echo "Error: gh CLI not installed" >&2; exit 2; }
command -v git >/dev/null || { echo "Error: git not installed" >&2; exit 2; }

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh CLI not authenticated. Run: gh auth login" >&2
  exit 2
fi

# Semver comparison helper (returns 0 if a <= b)
semver_le() {
  [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -1)" == "$1" ]]
}

echo "== Release Backfill =="
echo ""

# Get all tags sorted by version
TAGS=$(git tag -l "v*.*.*" | sort -V)
TOTAL_TAGS=$(echo "$TAGS" | wc -l)
echo "Total tags found: $TOTAL_TAGS"

# Get all existing releases
EXISTING=$(gh release list --limit 1000 2>/dev/null | awk '{print $1}' | grep -E "^v[0-9]" || true)
EXISTING_COUNT=$(echo "$EXISTING" | grep -c "^v" || echo 0)
echo "Existing releases: $EXISTING_COUNT"
echo ""

# Compute missing
MISSING=()
while read -r tag; do
  [[ -z "$tag" ]] && continue

  # Apply from/to filters
  if [[ -n "$FROM_VERSION" ]]; then
    semver_le "$FROM_VERSION" "${tag#v}" || continue
  fi
  if [[ -n "$TO_VERSION" ]]; then
    semver_le "${tag#v}" "$TO_VERSION" || continue
  fi

  if echo "$EXISTING" | grep -qFx "$tag"; then
    [[ "$FORCE" == "true" ]] && MISSING+=("$tag")
  else
    MISSING+=("$tag")
  fi
done <<< "$TAGS"

MISSING_COUNT=${#MISSING[@]}
echo "Releases to create: $MISSING_COUNT"

if [[ "$LIMIT" -gt 0 && "$LIMIT" -lt "$MISSING_COUNT" ]]; then
  MISSING=("${MISSING[@]:0:$LIMIT}")
  echo "Limited to first $LIMIT"
fi
echo ""

# Dry run exit
if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== DRY RUN — would create: ==="
  printf '  %s\n' "${MISSING[@]}"
  exit 0
fi

# Process each missing release
CREATED=0
FAILED=0
for tag in "${MISSING[@]}"; do
  SEMVER="${tag#v}"
  echo "-- Processing $tag --"

  # Extract changelog section
  NOTES=$(awk "/^## \[${SEMVER}\]/{found=1; next} /^## \[/{if(found) exit} found{print}" CHANGELOG.md)

  if [[ -z "$NOTES" ]]; then
    NOTES="No changelog entry found for version ${SEMVER}. See CHANGELOG.md for full history."
  fi

  # Save to temp file (gh release create prefers --notes-file for multiline)
  TMPF=$(mktemp)
  echo "$NOTES" > "$TMPF"

  # Create release
  if [[ "$FORCE" == "true" ]] && gh release view "$tag" >/dev/null 2>&1; then
    if gh release edit "$tag" --notes-file "$TMPF" --title "PM Workspace $tag" 2>/dev/null; then
      echo "  ✅ Updated existing release"
      CREATED=$((CREATED + 1))
    else
      echo "  ❌ Failed to update"
      FAILED=$((FAILED + 1))
    fi
  else
    if gh release create "$tag" \
        --title "PM Workspace $tag" \
        --notes-file "$TMPF" \
        --verify-tag 2>/dev/null; then
      echo "  ✅ Created release"
      CREATED=$((CREATED + 1))
    else
      echo "  ❌ Failed to create"
      FAILED=$((FAILED + 1))
    fi
  fi

  rm -f "$TMPF"
done

echo ""
echo "== Summary =="
echo "  Created: $CREATED"
echo "  Failed:  $FAILED"
echo "  Total processed: $MISSING_COUNT"

[[ "$FAILED" -gt 0 ]] && exit 1 || exit 0
