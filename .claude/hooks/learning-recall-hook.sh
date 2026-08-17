#!/usr/bin/env bash
# SCL-003/SCL-008 — inject only human-authorized criteria at prompt submit.
set -uo pipefail

[[ "${SAVIA_LEARNING_RECALL:-on}" == "on" ]] || exit 0
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
RECALL_SCRIPT="$REPO_ROOT/scripts/learning-recall.sh"
[[ -f "$RECALL_SCRIPT" ]] || exit 0

USER_INPUT=$(cat 2>/dev/null || true)
[[ -n "$USER_INPUT" ]] || exit 0
INPUT_TEXT=$(SCL_INPUT="$USER_INPUT" python3 - <<'PY' 2>/dev/null || true
import json, os
try:
    data = json.loads(os.environ['SCL_INPUT'])
except Exception:
    raise SystemExit
for key in ('content', 'prompt_text'):
    value = data.get(key)
    if isinstance(value, str):
        print(value)
        break
PY
)
[[ -n "$INPUT_TEXT" && ${#INPUT_TEXT} -ge 8 && "$INPUT_TEXT" != /* ]] || exit 0
echo "$INPUT_TEXT" | grep -qiE '^(s[ií]|no|ok|vale|claro|hecho|listo|adelante|gracias|y|n)$' && exit 0

ARGS=(--query "$INPUT_TEXT" --top 3 --min-score 10 --mode effective --json)
[[ -n "${SCL_CRITERIO_PATH:-}" ]] && ARGS+=(--criterio "$SCL_CRITERIO_PATH")
LEARNINGS=$(timeout 4 bash "$RECALL_SCRIPT" "${ARGS[@]}" 2>/dev/null) || exit 0
[[ -n "$LEARNINGS" ]] || exit 0

SCL_LEARNINGS="$LEARNINGS" python3 - <<'PY' 2>/dev/null || true
import json, os
try:
    hits = json.loads(os.environ['SCL_LEARNINGS']).get('effective_hits', [])
except Exception:
    raise SystemExit
if not hits:
    raise SystemExit
lines = ['## Criterios humanos aplicables', '']
for hit in hits[:3]:
    lines.append(f"- [{hit['criterion_id']}] {hit['principle']}")
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'UserPromptSubmit', 'additionalContext': '\n'.join(lines)}}, ensure_ascii=False))
PY
exit 0
