#!/usr/bin/env bash
# changelog-consolidate.sh — consolidate CHANGELOG.d/*.md fragments into
# CHANGELOG.md at release time. Runs ONCE per release; deletes fragments
# after consolidation. Zero conflicts between PRs because each PR only
# adds a file in CHANGELOG.d/ and never touches CHANGELOG.md.
#
# Usage:
#   changelog-consolidate.sh [--version X.Y.Z] [--dry-run]
#
# Version selection:
#   - If --version given: use it.
#   - Else: look at `version_bump:` in each fragment's frontmatter, apply
#     the highest level (major > minor > patch) to the current top version
#     in CHANGELOG.md.
#
# Ref: CHANGELOG.d/README.md.
# Safety: `set -uo pipefail`. Dry-run mode available.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FRAGMENTS_DIR="$REPO_ROOT/CHANGELOG.d"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"

NEW_VERSION=""
DRY_RUN=0

usage() {
  cat <<EOF
Usage: $0 [--version X.Y.Z] [--dry-run]

  --version X.Y.Z   Explicit version for this release (skips auto-bump).
  --dry-run         Show planned consolidation, do not write.

Consolidates CHANGELOG.d/*.md fragments into CHANGELOG.md at release.
After a successful run, fragments are deleted.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) NEW_VERSION="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

if [[ ! -d "$FRAGMENTS_DIR" ]]; then
  echo "No CHANGELOG.d/ directory — nothing to consolidate"
  exit 0
fi

fragments=$(find "$FRAGMENTS_DIR" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | sort)
if [[ -z "$fragments" ]]; then
  echo "No fragments in CHANGELOG.d/ — nothing to consolidate"
  exit 0
fi

fragment_count=$(echo "$fragments" | wc -l)
echo "changelog-consolidate: $fragment_count fragment(s) found"

# ── Compute version ────────────────────────────────────────────────────────

if [[ -z "$NEW_VERSION" ]]; then
  # Find current top version in CHANGELOG.md.
  current=$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$CHANGELOG" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  if [[ -z "$current" ]]; then
    echo "ERROR: cannot determine current version from $CHANGELOG" >&2
    exit 2
  fi

  # Find highest bump level across fragments.
  highest_bump="patch"
  while IFS= read -r frag; do
    bump=$(grep -m1 -E '^version_bump:' "$frag" | awk '{print $2}')
    case "$bump" in
      major) highest_bump="major"; break ;;
      minor) [[ "$highest_bump" != "major" ]] && highest_bump="minor" ;;
    esac
  done <<< "$fragments"

  IFS='.' read -r maj min pat <<< "$current"
  case "$highest_bump" in
    major) NEW_VERSION="$((maj+1)).0.0" ;;
    minor) NEW_VERSION="${maj}.$((min+1)).0" ;;
    patch) NEW_VERSION="${maj}.${min}.$((pat+1))" ;;
  esac
  echo "  current = $current, bump = $highest_bump, new = $NEW_VERSION"
else
  echo "  explicit version = $NEW_VERSION"
fi

# ── Group fragments by section ─────────────────────────────────────────────

declare -A SECTIONS
SECTIONS["Added"]=""
SECTIONS["Changed"]=""
SECTIONS["Fixed"]=""
SECTIONS["Removed"]=""
SECTIONS["Security"]=""
SECTIONS["Deprecated"]=""

while IFS= read -r frag; do
  # Extract the body (skip YAML frontmatter).
  in_fm=0
  fm_ended=0
  current_section=""
  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      if [[ "$in_fm" -eq 0 ]]; then in_fm=1; continue; fi
      if [[ "$in_fm" -eq 1 && "$fm_ended" -eq 0 ]]; then fm_ended=1; continue; fi
    fi
    [[ "$in_fm" -eq 1 && "$fm_ended" -eq 0 ]] && continue

    # Detect section headers.
    if [[ "$line" =~ ^###[[:space:]]+(Added|Changed|Fixed|Removed|Security|Deprecated)$ ]]; then
      current_section="${BASH_REMATCH[1]}"
      continue
    fi

    # Collect bullets under current section.
    if [[ -n "$current_section" && "$line" =~ ^- ]]; then
      SECTIONS["$current_section"]+="$line"$'\n'
    fi
  done < "$frag"
done <<< "$fragments"

# ── Build new CHANGELOG entry ──────────────────────────────────────────────

date_str=$(date +%Y-%m-%d)
new_entry="## [$NEW_VERSION] — $date_str"$'\n\n'
for section in Added Changed Fixed Removed Security Deprecated; do
  if [[ -n "${SECTIONS[$section]}" ]]; then
    new_entry+="### $section"$'\n\n'
    new_entry+="${SECTIONS[$section]}"$'\n'
  fi
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ""
  echo "=== Planned new entry ==="
  echo "$new_entry"
  echo "=== Fragments that would be deleted ==="
  echo "$fragments" | sed 's|^|  |'
  exit 0
fi

# ── Insert new entry into CHANGELOG.md ────────────────────────────────────

# Find the first "## [" header; insert new entry above it.
first_header=$(grep -nE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$CHANGELOG" | head -1 | cut -d: -f1)
if [[ -z "$first_header" ]]; then
  echo "ERROR: no existing version header found in $CHANGELOG" >&2
  exit 2
fi

tmp=$(mktemp)
{
  sed -n "1,$((first_header-1))p" "$CHANGELOG"
  echo "$new_entry"
  sed -n "${first_header},\$p" "$CHANGELOG"
} > "$tmp"
mv "$tmp" "$CHANGELOG"

# Add link line.
prev_version=$(grep -m1 -oE '^\[[0-9]+\.[0-9]+\.[0-9]+\]:' "$CHANGELOG" | head -1 | tr -d '[]:')
link_line="[$NEW_VERSION]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v${prev_version}...v${NEW_VERSION}"

# Find the first link line and insert our new link above it.
first_link_line=$(grep -nE '^\[[0-9]+\.[0-9]+\.[0-9]+\]:' "$CHANGELOG" | head -1 | cut -d: -f1)
if [[ -n "$first_link_line" ]]; then
  sed -i "${first_link_line}i\\
$link_line" "$CHANGELOG"
else
  echo "$link_line" >> "$CHANGELOG"
fi

# ── Delete consolidated fragments ──────────────────────────────────────────

while IFS= read -r frag; do
  rm -f "$frag"
done <<< "$fragments"

echo ""
echo "changelog-consolidate: ✅ consolidated $fragment_count fragment(s) into $NEW_VERSION"
echo "  commit: git add CHANGELOG.md CHANGELOG.d/ && git commit -m 'release: $NEW_VERSION'"
exit 0
