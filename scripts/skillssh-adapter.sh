#!/usr/bin/env bash
# ── skills.sh Adapter — Genera paquetes publicables para skills.sh ──
# Uso: bash scripts/skillssh-adapter.sh [skill-name|--all] [--dry-run]
set -euo pipefail

SKILLS_DIR=".claude/skills"
OUTPUT_DIR="output/skillssh"
VERSION="1.0.0"
AUTHOR="pm-workspace"
LICENSE_TYPE="MIT"
REPO_URL="https://github.com/gonzalezpazmonica/pm-workspace"

# Skills core para publicar (slug:skill-dir:display-name:category)
declare -A SKILLS_MAP=(
  ["pm-sprint"]="sprint-management:Sprint Management:project-management"
  ["pm-capacity"]="capacity-planning:Capacity Planning:planning"
  ["pm-pbi-decompose"]="pbi-decomposition:PBI Decomposition:planning"
  ["pm-sdd"]="spec-driven-development:Spec-Driven Development:development"
  ["pm-diagrams"]="diagram-generation:Diagram Generation:architecture"
)

DRY_RUN=false
TARGET="${1:---all}"
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN=true

log() { echo "  $1"; }
ok()  { echo "  ✅ $1"; }
err() { echo "  ❌ $1" >&2; }

generate_package() {
  local slug="$1"
  local info="${SKILLS_MAP[$slug]}"
  local skill_dir="${info%%:*}"
  local rest="${info#*:}"
  local display="${rest%%:*}"
  local category="${rest##*:}"
  local skill_file="${SKILLS_DIR}/${skill_dir}/SKILL.md"

  if [[ ! -f "$skill_file" ]]; then
    err "Skill not found: $skill_file"
    return 1
  fi

  local out="${OUTPUT_DIR}/${slug}"
  if $DRY_RUN; then
    log "[dry-run] Would generate: $out"
    return 0
  fi

  mkdir -p "$out/.claude/commands"

  # 1. Extract and adapt SKILL.md → command format
  # Remove frontmatter references to local files
  sed '/^references:/,/^---$/d' "$skill_file" \
    | sed 's|@\.claude/[^ ]*||g' \
    | sed '/^context_cost:/d' \
    > "$out/.claude/commands/${skill_dir}.md"

  # 2. Generate package.json
  cat > "$out/package.json" <<EOJSON
{
  "name": "@${AUTHOR}/${slug}",
  "version": "${VERSION}",
  "description": "${display} skill for AI-assisted project management",
  "keywords": ["claude-code", "pm-workspace", "${category}", "scrum", "agile"],
  "author": "${AUTHOR}",
  "license": "${LICENSE_TYPE}",
  "repository": {
    "type": "git",
    "url": "${REPO_URL}"
  }
}
EOJSON

  # 3. Generate README.md
  cat > "$out/README.md" <<EOREADME
# ${display}

> AI-powered ${category} skill for Claude Code and compatible agents.

## Install

\`\`\`bash
npx skillsadd ${AUTHOR}/${slug}
\`\`\`

## What it does

${display} skill from [pm-workspace](${REPO_URL}).
Part of a Scrum/Agile project management toolkit powered by AI agents.

## Category

${category}

## License

${LICENSE_TYPE}
EOREADME

  # 4. Copy LICENSE
  if [[ -f "LICENSE" ]]; then
    cp LICENSE "$out/LICENSE"
  fi

  ok "${slug} → ${out}"
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 skills.sh Adapter — PM-Workspace"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$TARGET" == "--all" ]]; then
  mkdir -p "$OUTPUT_DIR"
  count=0
  for slug in "${!SKILLS_MAP[@]}"; do
    generate_package "$slug" && ((count++)) || true
  done
  echo ""
  echo "  📊 Generated: ${count}/${#SKILLS_MAP[@]} packages"
else
  if [[ -n "${SKILLS_MAP[$TARGET]+x}" ]]; then
    mkdir -p "$OUTPUT_DIR"
    generate_package "$TARGET"
  else
    err "Unknown skill: $TARGET"
    echo "  Available: ${!SKILLS_MAP[*]}"
    exit 1
  fi
fi

echo ""
$DRY_RUN && echo "  ℹ️  Dry run — no files written" || \
  echo "  📁 Output: ${OUTPUT_DIR}/"
echo ""
