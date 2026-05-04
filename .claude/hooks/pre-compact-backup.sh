#!/bin/bash
# pre-compact-backup.sh — SPEC-026 + SPEC-016: Save session context before /compact
# PreCompact hook: extracts decisions/corrections, classifies by tier, persists.
# NEVER blocks compact (always exit 0).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORE_SCRIPT="$SCRIPT_DIR/../../scripts/memory-store.sh"

# Session-hot file for Tier B persistence (consumed by post-compaction.sh)
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ_SLUG=$(echo "$PROJ_DIR" | sed 's|[/:\]|-|g; s|^-||')
SESSION_HOT_DIR="$HOME/.claude/projects/$PROJ_SLUG/memory"
SESSION_HOT="$SESSION_HOT_DIR/session-hot.md"

# Read hook input from stdin (JSON with transcript data)
INPUT=$(cat 2>/dev/null || true)
[[ -z "$INPUT" ]] && exit 0

# ============================================================================
# TIER CLASSIFICATION (SPEC-016)
# ============================================================================

# Tier A (ephemeral) — discard: line numbers, temp paths, debug output
# Tier B (session-hot) — persist to session-hot.md: decisions, corrections, task state
# Tier C (permanent) — persist to memory-store.sh: lessons, conventions

classify_and_extract() {
    local input="$1"

    # Extract Tier B: decisions and corrections (session-relevant)
    local decisions corrections task_state
    decisions=$(echo "$input" | grep -ioE '(decid|chose|will use|switched to|went with|vamos con|elegimos|usaremos)[^"]{5,80}' | head -5 | tr '\n' '; ' || true)
    corrections=$(echo "$input" | grep -ioE '(no[, ]+not that|wrong|cambia|change to|eso no|incorrecto)[^"]{5,80}' | head -3 | tr '\n' '; ' || true)
    task_state=$(echo "$input" | grep -ioE '(working on|implementando|step [0-9]|slice [0-9]|fase [0-9])[^"]{5,60}' | head -2 | tr '\n' '; ' || true)

    # Extract Tier C: patterns and conventions (permanent value)
    local patterns
    patterns=$(echo "$input" | grep -ioE '(always|siempre|never|nunca|convention|patron|regla)[^"]{10,80}' | head -3 | tr '\n' '; ' || true)

    # Extract files touched (for context)
    local files
    files=$(echo "$input" | grep -oE '[a-zA-Z0-9/_-]+\.(ts|js|py|sh|cs|md|json|yaml|yml)' | sort -u | head -10 | tr '\n' ', ' || true)

    # --- Persist Tier B to session-hot.md ---
    local tier_b=""
    [[ -n "$decisions" ]] && tier_b="Decisions: $decisions"
    [[ -n "$corrections" ]] && tier_b="${tier_b:+$tier_b | }Corrections: $corrections"
    [[ -n "$task_state" ]] && tier_b="${tier_b:+$tier_b | }Task: $task_state"

    if [[ -n "$tier_b" ]]; then
        mkdir -p "$SESSION_HOT_DIR"
        {
            echo "## Session Context ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
            echo "$tier_b"
            [[ -n "$files" ]] && echo "Files: $files"
            echo ""
        } >> "$SESSION_HOT"
        # Trim to last 20 entries to prevent unbounded growth
        if [[ -f "$SESSION_HOT" ]] && [[ $(wc -l < "$SESSION_HOT") -gt 80 ]]; then
            tail -40 "$SESSION_HOT" > "$SESSION_HOT.tmp" && mv "$SESSION_HOT.tmp" "$SESSION_HOT"
        fi
    fi

    # --- Persist Tier C to memory-store ---
    local tier_c=""
    [[ -n "$patterns" ]] && tier_c="Patterns: $patterns"
    [[ -n "$decisions" ]] && tier_c="${tier_c:+$tier_c | }Decisions: $decisions"

    if [[ -n "$tier_c" ]] && [[ -f "$STORE_SCRIPT" ]]; then
        bash "$STORE_SCRIPT" session-summary \
            --accomplished "$tier_c" \
            ${files:+--files "$files"} \
            --goal "pre-compact auto-save" 2>/dev/null || true
    fi

    # Output summary for Claude (visible post-compact)
    local count=0
    [[ -n "$decisions" ]] && count=$((count + 1))
    [[ -n "$corrections" ]] && count=$((count + 1))
    [[ -n "$patterns" ]] && count=$((count + 1))
    if [[ $count -gt 0 ]]; then
        echo "Pre-compact: $count items extracted (Tier B→session-hot, Tier C→memory-store)."
    fi
}

classify_and_extract "$INPUT"

# SPEC-022 F2: Generate semantic compact summary
COMPACT_SCRIPT="$SCRIPT_DIR/../../scripts/semantic-compact.sh"
if [[ -f "$COMPACT_SCRIPT" ]]; then
    bash "$COMPACT_SCRIPT" 2>/dev/null || true
fi

# NEVER block compact
exit 0
