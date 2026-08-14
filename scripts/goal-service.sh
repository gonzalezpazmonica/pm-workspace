#!/usr/bin/env bash
# goal-service.sh — SE-326 S4: wrapper del goal service durable por sesión.
#
# Inspirado en deepseek-harness packages/goal/goal (SE-326). Estado durable en
# output/goals/{session}.json (nunca en el repo).
#
# Uso:
#   goal-service.sh <session> create --objective "..." [--max-goal-rounds N]
#   goal-service.sh <session> edit <id> <rev> [--objective "..."] [--max-goal-rounds N]
#   goal-service.sh <session> pause|resume|complete|block|clear <id> <rev> [...]
#   goal-service.sh <session> get
#   goal-service.sh <session> admit-round <id> <rev>
#
# Exit codes: 0 OK | 3 version-conflict | 4 not-found | 5 invalid-request
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SERVICE="$PROJECT_DIR/scripts/goal-service.py"

SESSION="${1:-}"
[[ -z "$SESSION" ]] && { echo "ERROR: session obligatoria" >&2; exit 2; }
shift

OP="${1:-}"
[[ -z "$OP" ]] && { echo "ERROR: operación obligatoria (create/edit/pause/resume/complete/block/clear/get/admit-round)" >&2; exit 2; }
shift

ARGS=(--id 0 --revision 0 --objective "" --max-goal-rounds 0 --code "" --message "")

# Las operaciones con id+rev toman posicionales tras la op
case "$OP" in
  edit|pause|resume|complete|block|clear|admit-round)
    ARGS[0]="--id";   ARGS[1]="${1:-0}"; shift 2>/dev/null || true
    ARGS[2]="--revision"; ARGS[3]="${1:-0}"; shift 2>/dev/null || true
    ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --objective)      ARGS[4]="--objective";      ARGS[5]="$2"; shift 2 ;;
    --max-goal-rounds) ARGS[6]="--max-goal-rounds"; ARGS[7]="$2"; shift 2 ;;
    --code)           ARGS[8]="--code";           ARGS[9]="$2"; shift 2 ;;
    --message)        ARGS[10]="--message";       ARGS[11]="$2"; shift 2 ;;
    *) shift ;;
  esac
done

python3 "$SERVICE" "$SESSION" "$OP" "${ARGS[@]}"
