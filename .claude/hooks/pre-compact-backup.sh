#!/bin/bash
# pre-compact-backup.sh — SPEC-026: Save session context before /compact
# PreCompact hook: extracts decisions and corrections, persists to memory-store.
# NEVER blocks compact (always exit 0).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORE_SCRIPT="$SCRIPT_DIR/../../scripts/memory-store.sh"

# Read hook input from stdin (JSON with transcript data)
INPUT=$(cat 2>/dev/null || true)

# Extract meaningful content from the session
# Look for decisions, corrections, and discoveries in the transcript
DECISIONS=""
CORRECTIONS=""
FILES_TOUCHED=""

if [[ -n "$INPUT" ]]; then
    # Extract text content — hook receives JSON, we grep for patterns
    DECISIONS=$(echo "$INPUT" | grep -ioE '(decid|chose|will use|switched to|went with|vamos con|elegimos|usaremos)[^"]{5,80}' | head -5 | tr '\n' '; ' || true)
    CORRECTIONS=$(echo "$INPUT" | grep -ioE '(no[, ]+not that|wrong|cambia|change to|eso no|incorrecto)[^"]{5,80}' | head -3 | tr '\n' '; ' || true)
    FILES_TOUCHED=$(echo "$INPUT" | grep -oE '[a-zA-Z0-9/_-]+\.(ts|js|py|sh|cs|md|json|yaml|yml)' | sort -u | head -10 | tr '\n' ', ' || true)
fi

# Only save if there's something meaningful
ACCOMPLISHED=""
[[ -n "$DECISIONS" ]] && ACCOMPLISHED="Decisions: $DECISIONS"
[[ -n "$CORRECTIONS" ]] && ACCOMPLISHED="${ACCOMPLISHED:+$ACCOMPLISHED }Corrections: $CORRECTIONS"

if [[ -n "$ACCOMPLISHED" ]]; then
    bash "$STORE_SCRIPT" session-summary \
        --accomplished "$ACCOMPLISHED" \
        ${FILES_TOUCHED:+--files "$FILES_TOUCHED"} \
        --goal "pre-compact auto-save" 2>/dev/null || true
fi

# NEVER block compact
exit 0
