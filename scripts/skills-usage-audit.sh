#!/usr/bin/env bash
# skills-usage-audit.sh — Audita uso de los 91 skills de pm-workspace.
# Reporta: referenced (invocado desde commands/agents), orphan (nadie lo llama),
# self-referenced (solo desde su propio SKILL.md).
#
# SPEC-109 action 10 — skills audit + deprecation candidates
# Usage: bash scripts/skills-usage-audit.sh [--output FILE]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown: $1" >&2; exit 2 ;;
  esac
done

declare -a referenced=()
declare -a orphan=()
declare -a self_only=()

for skill_dir in "$ROOT"/.claude/skills/*/; do
  skill=$(basename "$skill_dir")
  [[ -f "$skill_dir/SKILL.md" ]] || continue

  # Match: Skill("name"), /name, @.claude/skills/name, `name`, skill: name,
  # "skill name" in prose, or bare word boundary match in relevant files.
  pattern="Skill\(\"?${skill}\"?\)|/${skill}\b|@\.claude/skills/${skill}|\`${skill}\`|skill[:\\s]+${skill}\\b|skill ${skill}\\b"
  refs=$(grep -rlE "$pattern" \
    "$ROOT/.claude/commands/" \
    "$ROOT/.claude/agents/" \
    "$ROOT/CLAUDE.md" \
    "$ROOT/.claude/README.md" \
    "$ROOT/docs/" \
    2>/dev/null | grep -v "\.claude/skills/$skill/" | grep -v "docs/audits/" | wc -l)

  other_skills=$(grep -rlE "$pattern" "$ROOT/.claude/skills/" 2>/dev/null \
    | grep -v "\.claude/skills/$skill/" | wc -l)

  total=$((refs + other_skills))

  if [[ "$total" -eq 0 ]]; then
    orphan+=("$skill")
  elif [[ "$refs" -eq 0 && "$other_skills" -gt 0 ]]; then
    self_only+=("$skill:$other_skills")
  else
    referenced+=("$skill:$total")
  fi
done

total_skills=$(ls -d "$ROOT"/.claude/skills/*/ 2>/dev/null | wc -l)
echo "Skills Usage Audit"
echo "=================="
echo "Total skills: $total_skills"
echo "Referenced: ${#referenced[@]}"
echo "Self-only: ${#self_only[@]}"
echo "Orphan: ${#orphan[@]}"
echo ""

if [[ "${#orphan[@]}" -gt 0 ]]; then
  echo "ORPHAN (deprecation candidates):"
  printf "  - %s\n" "${orphan[@]}"
fi

if [[ -n "$OUTPUT" ]]; then
  {
    echo "# Skills Usage Audit"
    echo
    echo "Generated: $(date -Iseconds)"
    echo
    echo "## Summary"
    echo "- Total: $total_skills"
    echo "- Referenced: ${#referenced[@]}"
    echo "- Self-only: ${#self_only[@]}"
    echo "- Orphan: ${#orphan[@]}"
    echo
    echo "## Orphan skills (deprecation candidates)"
    for s in "${orphan[@]}"; do echo "- \`$s\`"; done
    echo
    echo "## Self-only"
    for s in "${self_only[@]}"; do echo "- \`$s\`"; done
    echo
    echo "## Referenced"
    for s in "${referenced[@]}"; do echo "- \`$s\`"; done
  } > "$OUTPUT"
  echo "Report: $OUTPUT"
fi

exit 0
