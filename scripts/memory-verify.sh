#!/usr/bin/env bash
# memory-verify.sh — Quality gate for memory compression (SPEC-041 P3)
# Usage: bash scripts/memory-verify.sh verify <topic_key>
#        bash scripts/memory-verify.sh check-all
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MEMORY_FILE="$HOME/.claude/projects/-home-monica-claude/memory/memory-store.jsonl"

cmd_verify() {
    local topic_key="${1:-}"
    if [[ -z "$topic_key" ]]; then
        echo "Usage: memory-verify.sh verify <topic_key>" >&2
        exit 1
    fi

    local entry
    entry=$(grep "\"topic_key\":\"$topic_key\"" "$MEMORY_FILE" 2>/dev/null | tail -1 || true)

    if [[ -z "$entry" ]]; then
        echo "Entry not found: $topic_key" >&2
        exit 1
    fi

    local quality
    quality=$(echo "$entry" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(d.get('quality', 'unverified'))
" 2>/dev/null || echo "unverified")

    local questions_count
    questions_count=$(echo "$entry" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(len(d.get('questions', [])))
" 2>/dev/null || echo "0")

    if [[ "$questions_count" -eq 0 ]]; then
        echo "No questions[] found for $topic_key — skipping verification (quality: unverified)"
        exit 0
    fi

    echo "Entry: $topic_key"
    echo "Questions: $questions_count"
    echo "Current quality: $quality"
    echo ""
    echo "To verify manually: check if compressed content answers all $questions_count questions"
    echo "Update quality with: bash scripts/memory-store.sh save --topic-key $topic_key --quality high|medium|low"
}

cmd_check_all() {
    local verified=0
    local unverified=0
    local low=0

    if [[ ! -f "$MEMORY_FILE" ]]; then
        echo "Memory file not found: $MEMORY_FILE" >&2
        exit 1
    fi

    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        local quality
        quality=$(echo "$line" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(d.get('quality', 'unverified'))
" 2>/dev/null || echo "unverified")

        case "$quality" in
            "high"|"medium") ((verified++)) ;;
            "low") ((low++)) ;;
            *) ((unverified++)) ;;
        esac
    done < "$MEMORY_FILE"

    echo "Memory Quality Report"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "  Verified (high/medium): $verified"
    echo "  Unverified:             $unverified"
    echo "  Low quality:            $low"

    if [[ $low -gt 0 ]]; then
        echo ""
        echo "  $low entries with low quality — consider re-compressing"
    fi
}

cmd="${1:-help}"
shift || true

case "$cmd" in
    verify) cmd_verify "$@" ;;
    check-all) cmd_check_all ;;
    help|--help|-h)
        echo "memory-verify.sh — Quality gate for memory compression (SPEC-041 P3)"
        echo ""
        echo "Commands:"
        echo "  verify <topic_key>  — Verify a specific memory entry"
        echo "  check-all           — Report quality stats across all entries"
        ;;
    *) echo "Unknown command: $cmd. Use 'help' for usage." >&2; exit 1 ;;
esac
