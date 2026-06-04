#!/usr/bin/env bash
# validate-frontmatter.sh — SPEC-184
# Warns if a SPEC/spec doc lacks required frontmatter fields.
# Always exits 0.
set -uo pipefail

FILE="${1:-}"
[[ -f "$FILE" ]] || exit 0

# Only check files that LOOK like specs (SPEC-* or in docs/propuestas/)
case "$FILE" in
  */docs/propuestas/SPEC-*.md|*/docs/propuestas/SE-*.md) ;;
  *) exit 0 ;;
esac

# Must have frontmatter delimiter on line 1
first=$(head -1 "$FILE")
if [[ "$first" != "---" ]]; then
  echo "[WARN][frontmatter][$FILE:1] missing YAML frontmatter (first line should be '---')" >&2
  exit 0
fi

# Extract frontmatter block (between first two ---)
fm=$(awk '/^---$/{c++; if(c==2)exit; if(c==1)next} c==1' "$FILE")

# Required fields for SPEC docs
required=(spec_id title status)
for field in "${required[@]}"; do
  if ! echo "$fm" | grep -qE "^${field}:"; then
    echo "[WARN][frontmatter][$FILE] missing required field '${field}:' in YAML frontmatter" >&2
  fi
done

exit 0
