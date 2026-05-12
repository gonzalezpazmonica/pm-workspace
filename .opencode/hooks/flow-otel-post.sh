#!/usr/bin/env bash
# flow-otel-post.sh — Hook post-tool OTel (SPEC-FLOW-OBSERVABILITY §2.4, SPEC-127).
# Sale 0 siempre — fallos del exporter NO interrumpen el flujo (D-1, D-3).
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh" 2>/dev/null || true
WORKSPACE="${SAVIA_WORKSPACE_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

[[ "${SAVIA_OTEL_ENABLED:-}" != "true" ]] && exit 0

HOOK_INPUT="$(cat -)"
TOOL_NAME="$(printf '%s' "$HOOK_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")"
case "$TOOL_NAME" in Bash|bash) ;; *) exit 0 ;; esac

TOOL_CMD="$(printf '%s' "$HOOK_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")"
case "$TOOL_CMD" in *flow_runner*|*flow-run*|*flow_run*) ;; *) exit 0 ;; esac

OUTPUT_DIR="$WORKSPACE/output/flows"
TRACE_FILE="$(ls -t "$OUTPUT_DIR"/*/trace.jsonl 2>/dev/null | head -1)"
[[ -z "$TRACE_FILE" ]] && { echo "flow-otel-post: no trace found" >&2; exit 0; }

bash "$WORKSPACE/scripts/flow-otel-exporter.sh" "$TRACE_FILE" >&2 || true
exit 0
