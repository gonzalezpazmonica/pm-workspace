#!/bin/bash
# semantic-compact.sh — SPEC-022 F2: Smart compact summary generator
# Analyzes recent session activity and generates a focused compact summary
# that preserves critical context. Called by pre-compact hook or manually.
# Usage: bash scripts/semantic-compact.sh [--project NAME]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

PROJECT=""
while [[ $# -gt 0 ]]; do
    case "$1" in --project) PROJECT="$2"; shift 2;; *) shift;; esac
done

# --- Gather signals from the session ---

# 1. Recently modified files (git)
RECENT_FILES=""
if git -C "$ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
    RECENT_FILES=$(git -C "$ROOT" diff --name-only HEAD~5 HEAD 2>/dev/null | head -10 | tr '\n' ', ' || true)
fi

# 2. Recent memory entries (last 5)
RECENT_MEMORIES=""
STORE="${ROOT}/output/.memory-store.jsonl"
if [[ -f "$STORE" ]]; then
    RECENT_MEMORIES=$(tail -5 "$STORE" 2>/dev/null | while IFS= read -r line; do
        title=$(echo "$line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
        type=$(echo "$line" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
        [[ -n "$title" ]] && echo "  - ($type) $title"
    done || true)
fi

# 3. Current branch
BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || echo "unknown")

# 4. Last commands from agent-trace (if available)
LAST_COMMANDS=""
TRACE_DIR="$ROOT/output/agent-trace"
if [[ -d "$TRACE_DIR" ]]; then
    TODAY=$(date +%Y-%m-%d)
    LAST_COMMANDS=$(ls -t "$TRACE_DIR/${TODAY}"* 2>/dev/null | head -5 | while read -r f; do
        basename "$f" | sed 's/.*_//' | sed 's/\.json//'
    done | tr '\n' ', ' || true)
fi

# --- Generate compact summary ---

echo "Session context for compact:"
echo ""
echo "Branch: $BRANCH"
[[ -n "$PROJECT" ]] && echo "Project: $PROJECT"
echo ""

if [[ -n "$RECENT_FILES" ]]; then
    echo "Files modified: $RECENT_FILES"
fi

if [[ -n "$RECENT_MEMORIES" ]]; then
    echo "Recent decisions/discoveries:"
    echo "$RECENT_MEMORIES"
fi

if [[ -n "$LAST_COMMANDS" ]]; then
    echo "Recent commands: $LAST_COMMANDS"
fi

echo ""
echo "Preserve: file list, decisions, current task context."
echo "Discard: intermediate search results, verbose tool output, exploration dead ends."
