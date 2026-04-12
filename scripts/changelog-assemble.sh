#!/usr/bin/env bash
set -uo pipefail
# changelog-assemble.sh — Assemble CHANGELOG.md from CHANGELOG.d/ fragments
#
# Each fragment: CHANGELOG.d/{version}.md (e.g., CHANGELOG.d/4.50.0.md)
# Contains a single version entry starting with ## [{version}] — {date}
#
# Usage:
#   bash scripts/changelog-assemble.sh              # dry-run (stdout)
#   bash scripts/changelog-assemble.sh --apply       # write to CHANGELOG.md
#   bash scripts/changelog-assemble.sh --check       # verify fragments parseable

CHANGELOG="CHANGELOG.md"
FRAGMENTS_DIR="CHANGELOG.d"

die() { echo "ERROR: $*" >&2; exit 1; }

# Parse the existing CHANGELOG.md to extract:
# 1. Header (lines before first ## [)
# 2. Existing entries (everything from first ## [ onwards until link block)
# 3. Link block (lines matching ^\[X.Y.Z\]:)

header=""
entries=""
links=""
in_links=0

if [[ -f "$CHANGELOG" ]]; then
  while IFS= read -r line; do
    if [[ "$in_links" -eq 1 ]]; then
      links+="$line"$'\n'
    elif [[ "$line" =~ ^\[[0-9]+\.[0-9]+\.[0-9]+\]:\ https:// ]]; then
      in_links=1
      links+="$line"$'\n'
    elif [[ -z "$entries" && ! "$line" =~ ^##\ \[ ]]; then
      header+="$line"$'\n'
    else
      entries+="$line"$'\n'
    fi
  done < "$CHANGELOG"
fi

# Collect fragments and sort by version descending
fragment_entries=""
fragment_links=""
if [[ -d "$FRAGMENTS_DIR" ]]; then
  for f in "$FRAGMENTS_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    local_ver=$(basename "$f" .md)
    [[ "$local_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
    content=$(cat "$f")
    fragment_entries+="$content"$'\n\n'
    # Generate compare link — find prev version
    prev_minor=$(echo "$local_ver" | awk -F. '{ printf "%d.%d.0", $1, $2-1 }')
    repo_url="https://github.com/gonzalezpazmonica/pm-workspace"
    fragment_links+="[$local_ver]: $repo_url/compare/v$prev_minor...v$local_ver"$'\n'
  done
fi

case "${1:-}" in
  --check)
    count=$(find "$FRAGMENTS_DIR" -name "*.md" ! -name ".gitkeep" 2>/dev/null | wc -l)
    echo "Fragments: $count"
    find "$FRAGMENTS_DIR" -name "*.md" ! -name ".gitkeep" -exec basename {} .md \; 2>/dev/null | sort -V
    ;;
  --apply)
    if [[ -z "$fragment_entries" ]]; then
      echo "No fragments to assemble."
      exit 0
    fi
    # Build new CHANGELOG: header + fragments (newest first) + existing entries + combined links
    {
      printf '%s' "$header"
      printf '%s\n' "$fragment_entries"
      printf '%s' "$entries"
      printf '%s' "$fragment_links"
      printf '%s' "$links"
    } > "$CHANGELOG"
    # Clean up assembled fragments
    find "$FRAGMENTS_DIR" -name "*.md" ! -name ".gitkeep" -delete
    echo "Assembled $(echo "$fragment_links" | grep -c '^\[') fragments into $CHANGELOG"
    ;;
  *)
    # Dry run — show what would be assembled
    if [[ -z "$fragment_entries" ]]; then
      echo "No fragments to assemble."
      exit 0
    fi
    echo "=== Would prepend to $CHANGELOG ==="
    echo "$fragment_entries"
    echo "=== New links ==="
    echo "$fragment_links"
    ;;
esac
