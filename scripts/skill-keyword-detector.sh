#!/bin/bash
# skill-keyword-detector.sh — SE-203: detect which skills to auto-load based on keyword triggers
# Ref: docs/propuestas/SE-203-skill-keyword-triggers.md
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="${SAVIA_SKILLS_DIR:-$SCRIPT_DIR/../.opencode/skills}"
LIST_MODE=false
JSON_MODE=false
INPUT=""

usage() {
  echo "Usage: skill-keyword-detector.sh <text>" >&2
  echo "       skill-keyword-detector.sh --list" >&2
  echo "       skill-keyword-detector.sh --json <text>" >&2
  exit 2
}

# Parse flags
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --list)   LIST_MODE=true; shift ;;
    --json)   JSON_MODE=true; shift ;;
    --help)   usage ;;
    *)
      if [[ -z "$INPUT" ]]; then
        INPUT="$1"
      fi
      shift
      ;;
  esac
done

# Extract trigger.keywords block from a SKILL.md frontmatter
# Returns space-separated list of keywords (lowercased)
extract_keywords() {
  local skill_md="$1"
  # Use awk to parse the YAML frontmatter between --- delimiters
  awk '
    BEGIN { in_front=0; in_trigger=0; in_keywords=0 }
    /^---$/ {
      if (in_front == 0) { in_front=1; next }
      else { in_front=0; exit }
    }
    in_front == 0 { next }
    /^trigger:/ { in_trigger=1; next }
    in_trigger && /^  keywords:/ {
      # Inline list: keywords: [a, b, c]
      line=$0
      gsub(/^[[:space:]]*keywords:[[:space:]]*\[/, "", line)
      gsub(/\][[:space:]]*$/, "", line)
      # Remove quotes
      gsub(/"/, "", line)
      gsub(/'"'"'/, "", line)
      # Split by comma
      n=split(line, parts, /,[[:space:]]*/);
      for (i=1; i<=n; i++) {
        kw=parts[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", kw)
        if (kw != "") print tolower(kw)
      }
      in_keywords=1
      next
    }
    in_trigger && in_keywords == 0 && /^    - / {
      # Block list style
      kw=$0
      gsub(/^[[:space:]]*-[[:space:]]*/, "", kw)
      gsub(/"/, "", kw)
      gsub(/'"'"'/, "", kw)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", kw)
      if (kw != "") print tolower(kw)
      next
    }
    in_trigger && /^[^ ]/ && !/^trigger:/ { in_trigger=0; in_keywords=0 }
  ' "$skill_md"
}

# --list mode: show all skills with their registered triggers
if $LIST_MODE; then
  printf "%-35s %s\n" "SKILL" "KEYWORDS"
  printf "%-35s %s\n" "-----" "--------"
  while IFS= read -r skill_md; do
    skill_name=$(basename "$(dirname "$skill_md")")
    keywords=$(extract_keywords "$skill_md" | tr '\n' ', ' | sed 's/, $//')
    if [[ -n "$keywords" ]]; then
      printf "%-35s %s\n" "$skill_name" "$keywords"
    fi
  done < <(find -L "$SKILLS_DIR" -name "SKILL.md" | sort)
  exit 0
fi

# Input required for detection
if [[ -z "$INPUT" ]]; then
  echo "Usage: skill-keyword-detector.sh <text>" >&2
  exit 2
fi

INPUT_LOWER=$(echo "$INPUT" | tr '[:upper:]' '[:lower:]')

matched_skills=()

while IFS= read -r skill_md; do
  skill_name=$(basename "$(dirname "$skill_md")")
  while IFS= read -r kw; do
    [[ -z "$kw" ]] && continue
    # Use fixed-string grep for the keyword in the lowercased input
    if echo "$INPUT_LOWER" | grep -qF "$kw"; then
      matched_skills+=("$skill_name")
      break  # one match per skill is enough
    fi
  done < <(extract_keywords "$skill_md")
done < <(find -L "$SKILLS_DIR" -name "SKILL.md" | sort)

if $JSON_MODE; then
  # Output JSON array
  printf '['
  first=true
  for s in "${matched_skills[@]+"${matched_skills[@]}"}"; do
    $first || printf ', '
    printf '"%s"' "$s"
    first=false
  done
  printf ']\n'
else
  for s in "${matched_skills[@]+"${matched_skills[@]}"}"; do
    echo "$s"
  done
fi

exit 0
