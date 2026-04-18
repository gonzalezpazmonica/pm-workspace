#!/usr/bin/env bash
# changelog-fragment.sh — create a CHANGELOG fragment for the current PR
# so that PRs don't conflict on CHANGELOG.md. Replaces direct edits of
# the top of CHANGELOG.md with per-PR fragment files in CHANGELOG.d/.
#
# Usage:
#   changelog-fragment.sh [--slug SLUG] [--version-bump {patch|minor|major}]
#                         [--section {Added|Changed|Fixed|Removed|Security|Deprecated}]
#                         [--entry "text"] [--from-stdin]
#
# Ref: CHANGELOG.d/README.md, SPEC-SE-012-like signal/noise.
# Safety: `set -uo pipefail`. Never edits CHANGELOG.md. Append-only.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FRAGMENTS_DIR="$REPO_ROOT/CHANGELOG.d"

SLUG=""
BUMP="minor"
SECTION="Changed"
ENTRIES=()
FROM_STDIN=0

usage() {
  cat <<EOF
Usage: $0 [--slug SLUG] [--version-bump TYPE] [--section SECTION]
          [--entry "text"] [--from-stdin]

  --slug SLUG          Fragment filename slug (default: current branch name).
  --version-bump TYPE  patch | minor | major (default: minor).
  --section SECTION    Added | Changed | Fixed | Removed | Security | Deprecated (default: Changed).
  --entry "text"       Bullet to include in the fragment.
  --from-stdin         Read entries from stdin (one bullet per line).

Creates: \$REPO_ROOT/CHANGELOG.d/<slug>.md

Never edits CHANGELOG.md — eliminates cross-PR conflicts on that file.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --version-bump) BUMP="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    --entry) ENTRIES+=("$2"); shift 2 ;;
    --from-stdin) FROM_STDIN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

# Validate BUMP.
case "$BUMP" in
  patch|minor|major) ;;
  *) echo "ERROR: --version-bump must be patch|minor|major" >&2; exit 2 ;;
esac

# Validate SECTION.
case "$SECTION" in
  Added|Changed|Fixed|Removed|Security|Deprecated) ;;
  *) echo "ERROR: --section must be one of Added|Changed|Fixed|Removed|Security|Deprecated" >&2; exit 2 ;;
esac

mkdir -p "$FRAGMENTS_DIR"

# Default slug from branch name.
if [[ -z "$SLUG" ]]; then
  SLUG=$(git rev-parse --abbrev-ref HEAD | sed 's|/|-|g')
fi

if [[ -z "$SLUG" || "$SLUG" == "HEAD" ]]; then
  echo "ERROR: could not determine slug (pass --slug explicitly)" >&2
  exit 2
fi

FRAGMENT="$FRAGMENTS_DIR/$SLUG.md"

# Collect entries.
entries=""
for e in "${ENTRIES[@]}"; do
  entries+="- $e"$'\n'
done
if [[ "$FROM_STDIN" -eq 1 ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Prefix with "- " if not already a bullet.
    if [[ "$line" =~ ^- ]]; then
      entries+="$line"$'\n'
    else
      entries+="- $line"$'\n'
    fi
  done
fi

if [[ -z "$entries" ]]; then
  echo "ERROR: no entries provided (use --entry or --from-stdin)" >&2
  exit 2
fi

# If fragment already exists, APPEND entries under the same section (idempotent usage).
if [[ -f "$FRAGMENT" ]]; then
  # Check if the section already exists in the fragment.
  if grep -qE "^### $SECTION$" "$FRAGMENT"; then
    # Append to existing section.
    awk -v section="### $SECTION" -v new_entries="$entries" '
      $0 == section { print; in_section=1; next }
      /^### / && in_section { print new_entries; in_section=0 }
      { print }
      END { if (in_section) print new_entries }
    ' "$FRAGMENT" > "$FRAGMENT.tmp" && mv "$FRAGMENT.tmp" "$FRAGMENT"
  else
    # Add new section to existing fragment.
    printf "\n### %s\n\n%s" "$SECTION" "$entries" >> "$FRAGMENT"
  fi
  echo "changelog-fragment: appended to $FRAGMENT (section $SECTION)"
else
  # Create fresh fragment.
  {
    echo "---"
    echo "version_bump: $BUMP"
    echo "section: $SECTION"
    echo "---"
    echo ""
    echo "### $SECTION"
    echo ""
    echo "$entries"
  } > "$FRAGMENT"
  echo "changelog-fragment: created $FRAGMENT (bump=$BUMP section=$SECTION)"
fi

echo "  git add CHANGELOG.d/$SLUG.md"
exit 0
