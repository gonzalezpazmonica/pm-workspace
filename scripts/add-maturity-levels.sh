#!/usr/bin/env bash
# add-maturity-levels.sh — Add maturity field to all skill frontmatter
# Maturity levels: alpha | beta | stable
# Criteria:
#   stable  = has SKILL.md + frontmatter with name+description + ≥50 lines of content
#   beta    = has SKILL.md + frontmatter with name+description
#   alpha   = has SKILL.md but missing frontmatter or key fields
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$ROOT/.claude/skills"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

MODE="${1:---summary}"
ALPHA=0 BETA=0 STABLE=0 MISSING=0 ALREADY=0

for dir in "$SKILLS_DIR"/*/; do
  [ -d "$dir" ] || continue
  skill_name=$(basename "$dir")
  skill_file="$dir/SKILL.md"

  if [ ! -f "$skill_file" ]; then
    MISSING=$((MISSING + 1))
    [ "$MODE" = "--verbose" ] && echo "  ⚠️  MISSING: $skill_name (no SKILL.md)"
    continue
  fi

  # Check if already has maturity field
  if head -20 "$skill_file" | grep -q "^maturity:"; then
    ALREADY=$((ALREADY + 1))
    [ "$MODE" = "--verbose" ] && echo "  ⏭️  SKIP: $skill_name (already has maturity)"
    continue
  fi

  # Determine maturity level
  has_frontmatter=false
  has_name=false
  has_description=false
  content_lines=0

  if head -1 "$skill_file" | grep -q "^---$"; then
    has_frontmatter=true
    # Count lines after frontmatter
    content_lines=$(awk '/^---$/{n++; if(n==2) start=1; next} start{print}' "$skill_file" | wc -l)
    head -20 "$skill_file" | grep -q "^name:" && has_name=true
    head -20 "$skill_file" | grep -q "^description:" && has_description=true
  else
    content_lines=$(wc -l < "$skill_file")
  fi

  if $has_frontmatter && $has_name && $has_description && [ "$content_lines" -ge 50 ]; then
    maturity="stable"
    STABLE=$((STABLE + 1))
  elif $has_frontmatter && $has_name && $has_description; then
    maturity="beta"
    BETA=$((BETA + 1))
  else
    maturity="alpha"
    ALPHA=$((ALPHA + 1))
  fi

  [ "$MODE" = "--verbose" ] && echo "  📋 $maturity: $skill_name (fm=$has_frontmatter, name=$has_name, desc=$has_description, lines=$content_lines)"

  # Add maturity field to frontmatter
  if $has_frontmatter; then
    # Insert maturity after the description line (or after first ---)
    if grep -q "^description:" "$skill_file"; then
      sed -i "/^description:/a maturity: $maturity" "$skill_file"
    else
      sed -i "0,/^---$/!{0,/^---$/s/^---$/maturity: $maturity\n---/}" "$skill_file"
    fi
  else
    # Add frontmatter block
    # Try to extract name from first # heading
    heading_name=$(grep -m1 "^# " "$skill_file" | sed 's/^# //')
    if [ -z "$heading_name" ]; then
      heading_name="$skill_name"
    fi
    # Prepend frontmatter (use TMPDIR which is cleaned up on EXIT)
    tmp="$TMPDIR/frontmatter-$skill_name.tmp"
    cat > "$tmp" << FM
---
name: $skill_name
description: $heading_name
maturity: $maturity
---

FM
    cat "$skill_file" >> "$tmp"
    mv "$tmp" "$skill_file"
  fi
done

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Maturity Level Summary"
echo "═══════════════════════════════════════════════════"
echo "  🟢 stable:  $STABLE"
echo "  🟡 beta:    $BETA"
echo "  🔴 alpha:   $ALPHA"
echo "  ⏭️  already: $ALREADY"
echo "  ⚠️  missing: $MISSING"
echo "  Total: $((STABLE + BETA + ALPHA + ALREADY + MISSING))"
echo "═══════════════════════════════════════════════════"
