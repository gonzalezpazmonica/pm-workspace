#!/usr/bin/env bash
# backlog-init.sh — Initialize local backlog structure for a project
# Usage: ./scripts/backlog-init.sh <project-path>
# ─────────────────────────────────────────────────────────────────
set -uo pipefail
cat /dev/stdin > /dev/null 2>&1 || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."
TEMPLATES="${ROOT}/.claude/templates/backlog"

PROJECT_PATH="${1:-}"
if [ -z "$PROJECT_PATH" ]; then
  echo "Usage: $0 <project-path>" >&2
  echo "Example: $0 projects/my-project" >&2
  exit 1
fi

# Resolve relative to ROOT if needed
[[ "$PROJECT_PATH" != /* ]] && PROJECT_PATH="${ROOT}/${PROJECT_PATH}"

if [ ! -d "$PROJECT_PATH" ]; then
  echo "Error: Project directory not found: $PROJECT_PATH" >&2
  exit 1
fi

BACKLOG="${PROJECT_PATH}/backlog"

if [ -d "$BACKLOG" ]; then
  echo "Backlog already exists: ${BACKLOG}"
  exit 0
fi

# ── Create structure ──
mkdir -p "$BACKLOG/pbi" "$BACKLOG/sprints" "$BACKLOG/archive"

# ── Generate config from template ──
PROJECT_NAME=$(basename "$PROJECT_PATH")
DATE=$(date +%Y-%m-%d)

sed -e "s/{PROJECT}/${PROJECT_NAME}/g" \
    -e "s/{DATE}/${DATE}/g" \
    "$TEMPLATES/config-template.yaml" > "$BACKLOG/_config.yaml"

# ── Create current sprint pointer ──
SPRINT_ID=$(date +%Y-S%V)
mkdir -p "$BACKLOG/sprints/${SPRINT_ID}"
sed -e "s/{SPRINT_ID}/${SPRINT_ID}/g" \
    -e "s/{GOAL}/Sprint goal TBD/g" \
    -e "s/{START}/${DATE}/g" \
    -e "s/{END}/$(date -d '+14 days' +%Y-%m-%d 2>/dev/null || date -v+14d +%Y-%m-%d 2>/dev/null || echo 'TBD')/g" \
    "$TEMPLATES/sprint-meta-template.yaml" > "$BACKLOG/sprints/${SPRINT_ID}/sprint-meta.yaml"

echo "# Sprint ${SPRINT_ID} Items" > "$BACKLOG/sprints/${SPRINT_ID}/items.md"
echo "" >> "$BACKLOG/sprints/${SPRINT_ID}/items.md"
echo "| PBI | Title | State | Assigned | SP |" >> "$BACKLOG/sprints/${SPRINT_ID}/items.md"
echo "|-----|-------|-------|----------|----|" >> "$BACKLOG/sprints/${SPRINT_ID}/items.md"

echo "${SPRINT_ID}" > "$BACKLOG/_current-sprint.md"

echo "Backlog initialized: ${BACKLOG}"
echo "  Config: _config.yaml"
echo "  Sprint: sprints/${SPRINT_ID}/"
echo "  PBIs:   pbi/ (empty)"
