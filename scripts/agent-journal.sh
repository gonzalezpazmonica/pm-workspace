#!/usr/bin/env bash
# agent-journal.sh — Append-only JSONL journal para agent-runs autónomos.
# Cada acción (task_claimed, pr_created, crash, skip) se registra como 1 línea JSON.
# Inspirado en henriquebastos/beans (SPEC-112).
#
# Usage:
#   bash scripts/agent-journal.sh append \
#     --actor "agent/overnight-20260417" \
#     --action "pr_created" \
#     --target "AB#456" \
#     --result "PR#587 draft"
#
#   bash scripts/agent-journal.sh tail 10
#   bash scripts/agent-journal.sh list  # lista ficheros journal por día

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."
JOURNAL_ROOT="${ROOT}/output/agent-runs"
TODAY=$(date +%Y%m%d)
JOURNAL_FILE="${JOURNAL_ROOT}/${TODAY}/journal.jsonl"

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  append)
    ACTOR=""
    EVT=""
    TARGET=""
    RESULT=""
    META="{}"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --actor) ACTOR="$2"; shift 2 ;;
        --action) EVT="$2"; shift 2 ;;
        --target) TARGET="$2"; shift 2 ;;
        --result) RESULT="$2"; shift 2 ;;
        --meta) META="$2"; shift 2 ;;
        *) echo "Unknown: $1" >&2; exit 2 ;;
      esac
    done
    [[ -z "$ACTOR" || -z "$EVT" ]] && { echo "ERROR: --actor and --action required" >&2; exit 2; }
    mkdir -p "$(dirname "$JOURNAL_FILE")"
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    python3 -c "
import json, sys
entry = {
  'ts': '$TS',
  'actor': '$ACTOR',
  'action': '$EVT',
  'target': '$TARGET',
  'result': '$RESULT',
  'meta': json.loads('''$META''')
}
print(json.dumps(entry, ensure_ascii=False))
" >> "$JOURNAL_FILE"
    echo "LOGGED $EVT → $JOURNAL_FILE"
    ;;
  tail)
    N="${1:-20}"
    [[ -f "$JOURNAL_FILE" ]] && tail -n "$N" "$JOURNAL_FILE" || echo "No journal for today yet."
    ;;
  list)
    find "$JOURNAL_ROOT" -name 'journal.jsonl' 2>/dev/null | sort
    ;;
  help|*)
    sed -n '2,15p' "$0"
    ;;
esac

exit 0
