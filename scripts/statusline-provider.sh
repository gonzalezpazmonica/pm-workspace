#!/usr/bin/env bash
# statusline-provider.sh — HUD data provider for Claude Code statusline
# Outputs single-line JSON with context %, active project, health score.
# Usage: ./scripts/statusline-provider.sh
# Configure in Claude Code: /statusline → Custom → this script
# ─────────────────────────────────────────────────────────────────
set -uo pipefail
cat /dev/stdin > /dev/null 2>&1 || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."

# ── Model info ──
TIER="${SAVIA_MODEL_TIER:-fast}"
WINDOW="${SAVIA_CONTEXT_WINDOW:-128000}"
COMPACT="${SAVIA_COMPACT_THRESHOLD:-50}"

# ── Active project ──
PROJECT="none"
SNAPSHOT="${ROOT}/.claude/context-cache/last-session.json"
if [ -f "$SNAPSHOT" ]; then
  PROJECT=$(grep -oP '"project":"[^"]*"' "$SNAPSHOT" 2>/dev/null | head -1 | cut -d'"' -f4) || true
fi
[ -z "$PROJECT" ] && PROJECT="none"

# ── Branch ──
BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || echo "N/A")

# ── Backlog stats (if backlog exists for project) ──
PBI_COUNT=0
ACTIVE_COUNT=0
if [ "$PROJECT" != "none" ] && [ -d "$ROOT/projects/$PROJECT/backlog/pbi" ]; then
  PBI_COUNT=$(find "$ROOT/projects/$PROJECT/backlog/pbi" -name "PBI-*.md" 2>/dev/null | grep -c . || echo 0)
  ACTIVE_COUNT=$(grep -rl "^state: Active" "$ROOT/projects/$PROJECT/backlog/pbi/" 2>/dev/null | grep -c . || echo 0)
fi

# ── BATS test count ──
TEST_COUNT=$(find "$ROOT/tests" -name "*.bats" 2>/dev/null | grep -c . || echo 0)

# ── Output ──
printf '{"tier":"%s","window":%s,"compact":%s,"project":"%s","branch":"%s","pbis":%s,"active":%s,"tests":%s}\n' \
  "$TIER" "$WINDOW" "$COMPACT" "$PROJECT" "$BRANCH" "$PBI_COUNT" "$ACTIVE_COUNT" "$TEST_COUNT"
