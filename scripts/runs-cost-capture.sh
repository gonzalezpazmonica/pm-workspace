#!/usr/bin/env bash
set -uo pipefail
# runs-cost-capture.sh — SubagentStop hook (SE-405 Slice 1).
#
# Si el entorno trae SAVIA_RUN_ID (run autónomo registrado en savia-runs.sh),
# suma el `usage` de los mensajes del transcript del subagente y lo añade al
# hecho `cost` del run. Sin SAVIA_RUN_ID o sin transcript legible: no hace nada.
# Nunca bloquea: exit 0 siempre.
# Ref: docs/specs/SE-405-harness-observability-increments.spec.md

[[ -z "${SAVIA_RUN_ID:-}" ]] && exit 0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
payload=$(cat 2>/dev/null) || exit 0
summary=$(python3 - "$payload" <<'PY' 2>/dev/null
import json, sys
try:
    p = json.loads(sys.argv[1] or "{}")
except json.JSONDecodeError:
    sys.exit(0)
path = p.get("agent_transcript_path") or p.get("transcript_path")
if not path:
    sys.exit(0)
tin = tout = 0
model = ""
try:
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            try:
                m = json.loads(line).get("message") or {}
            except json.JSONDecodeError:
                continue
            u = m.get("usage") or {}
            tin += int(u.get("input_tokens", 0) or 0)
            tout += int(u.get("output_tokens", 0) or 0)
            model = m.get("model") or model
except OSError:
    sys.exit(0)
agent = p.get("agent_type") or p.get("agent_id") or "subagent"
print(f"{agent}\t{model or 'unknown'}\t{tin}\t{tout}")
PY
) || exit 0
[[ -z "$summary" ]] && exit 0
IFS=$'\t' read -r agent model tin tout <<<"$summary"
bash "$SCRIPT_DIR/savia-runs.sh" cost "$SAVIA_RUN_ID" --agent "$agent" --model "$model" \
  --tokens-in "$tin" --tokens-out "$tout" >/dev/null 2>&1 || true
exit 0
