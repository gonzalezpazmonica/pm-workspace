#!/bin/bash
# build-skill-manifest.sh — Genera manifesto de skills desde frontmatter
# Uso: bash scripts/build-skill-manifest.sh [SKILLS_DIR]
# Output: .claude/skill-manifests.json
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: build-skill-manifest.sh <skills-dir> [output-file]" >&2
  exit 1
fi

SKILLS_DIR="$1"
OUTPUT="${2:-.claude/skill-manifests.json}"

# Verificar que el directorio existe
if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "ERROR: SKILLS_DIR no encontrado: $SKILLS_DIR" >&2
  exit 1
fi

echo "Construyendo manifesto de skills desde $SKILLS_DIR..." >&2

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TOTAL=0
SKILLS_JSON=""

for skill_dir in "$SKILLS_DIR"/*/; do
  [[ -d "$skill_dir" ]] || continue
  SKILL_FILE="$skill_dir/SKILL.md"
  [[ -f "$SKILL_FILE" ]] || continue

  NAME=$(basename "$skill_dir")

  # Extraer campos desde frontmatter YAML (entre los --- delimitadores)
  DESC=$(grep -m1 '^description:' "$SKILL_FILE" 2>/dev/null | sed 's/^description: *//' | tr -d '"' | head -c120 || true)
  CATEGORY=$(grep -m1 '^category:' "$SKILL_FILE" 2>/dev/null | sed 's/^category: *//' | tr -d '"' || true)
  MATURITY=$(grep -m1 '^maturity:' "$SKILL_FILE" 2>/dev/null | sed 's/^maturity: *//' | tr -d '"' || true)
  TOKENS=$(wc -c < "$SKILL_FILE" | awk '{print int($1/4)}')

  # Defaults para campos vacíos
  [[ -z "$DESC" ]] && DESC="$NAME skill"
  [[ -z "$CATEGORY" ]] && CATEGORY="general"
  [[ -z "$MATURITY" ]] && MATURITY="stable"

  # Escapar caracteres especiales JSON en DESC (comillas y backslashes)
  DESC=$(echo "$DESC" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

  ENTRY="{\"name\":\"$NAME\",\"description\":\"$DESC\",\"path\":\"$SKILL_FILE\",\"category\":\"$CATEGORY\",\"tokens_est\":$TOKENS,\"maturity\":\"$MATURITY\"}"

  if [[ $TOTAL -gt 0 ]]; then
    SKILLS_JSON="$SKILLS_JSON,$ENTRY"
  else
    SKILLS_JSON="$ENTRY"
  fi
  TOTAL=$((TOTAL + 1))
done

cat > "$OUTPUT" << EOF
{
  "generated": "$TS",
  "total_skills": $TOTAL,
  "skills": [$SKILLS_JSON]
}
EOF

echo "Manifesto generado: $TOTAL skills → $OUTPUT" >&2
