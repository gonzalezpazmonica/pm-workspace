#!/bin/bash
set -uo pipefail
# skill-audit.sh — Baseline skill catalog quality auditor (SE-084 Slice 1)
# Scans .claude/skills/*/SKILL.md for minimum quality requirements.
# Usage: bash scripts/skill-audit.sh [--check] [--strict]

STRICT=false
[[ "${1:-}" == "--strict" ]] && STRICT=true

SKILLS_DIR="${SKILLS_DIR:-.claude/skills}"
PASS=0
FAIL=0
WARN=0

echo "=== Skill Catalog Quality Audit ==="
echo ""

for skill_dir in "$SKILLS_DIR"/*/; do
  skill=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"
  issues=()

  # Check SKILL.md exists
  [[ ! -f "$skill_md" ]] && issues+=("MISSING SKILL.md") && FAIL=$((FAIL+1)) && continue

  # Check has YAML frontmatter (starts with ---)
  first_line=$(head -1 "$skill_md")
  [[ "$first_line" != "---" ]] && issues+=("no YAML frontmatter")

  # Check required frontmatter fields
  has_name=$(grep -c "^name:" "$skill_md" 2>/dev/null || echo 0)
  has_desc=$(grep -c "^description:" "$skill_md" 2>/dev/null || echo 0)
  [[ $has_name -eq 0 ]] && issues+=("missing 'name' field")
  [[ $has_desc -eq 0 ]] && issues+=("missing 'description' field")

  # Strict mode: check compatibility field
  if $STRICT; then
    has_compat=$(grep -c "^compatibility:" "$skill_md" 2>/dev/null || echo 0)
    [[ $has_compat -eq 0 ]] && issues+=("missing 'compatibility' field (provider-agnostic)")
  fi

  # Strict mode: check license
  if $STRICT; then
    has_license=$(grep -c "^license:" "$skill_md" 2>/dev/null || echo 0)
    [[ $has_license -eq 0 ]] && issues+=("missing 'license' field")
  fi

  # Check DOMAIN.md exists
  [[ ! -f "$skill_dir/DOMAIN.md" ]] && issues+=("missing DOMAIN.md")

  # Report
  if [[ ${#issues[@]} -eq 0 ]]; then
    PASS=$((PASS+1))
  elif [[ ${#issues[@]} -le 1 ]] && ! $STRICT; then
    echo "  WARN $skill: ${issues[*]}"
    WARN=$((WARN+1))
  else
    echo "  FAIL $skill: ${issues[*]}"
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "=== Results ==="
echo "  PASS: $PASS"
echo "  WARN: $WARN"
echo "  FAIL: $FAIL"
echo "  Total: $((PASS + WARN + FAIL)) skills audited"
echo ""

[[ $FAIL -gt 0 ]] && exit 1
exit 0
