#!/usr/bin/env bash
# sovereignty-decide.sh — SE-314 S2: decisión por umbral desde política YAML.
#
# Toma la salida de sovereignty-classify.sh (JSON) + destino (N1/N4) y decide
# la acción según config/sovereignty-thresholds.yaml. Los hard_block_rules
# SIEMPRE bloquean en N1 (fuga real), sin depender del LLM.
#
# Uso:
#   sovereignty-classify.sh ... | sovereignty-decide.sh [--context-path <path>] [--dest n1|n4]
#
# Salida (JSON): {action: ALLOW|WARN|BLOCK, reason, label, confidence, hard_block}
# Exit codes: 0 ALLOW/WARN, 1 BLOCK, 2 usage.
set -uo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
POLICY="$REPO_ROOT/config/sovereignty-thresholds.yaml"
DEST="n1"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --context-path) DEST="n1"; shift 2 ;;   # context-path público → n1
    --dest) DEST="$2"; shift 2 ;;
    *) echo "usage: sovereignty-decide.sh [--dest n1|n4]" >&2; exit 2 ;;
  esac
done

INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(cat 2>/dev/null)
fi
[[ -z "$INPUT" ]] && { echo "ERROR: salida de classifier requerida en stdin" >&2; exit 2; }

LABEL="$(printf '%s' "$INPUT" | jq -r '.label // empty' 2>/dev/null)"
CONF="$(printf '%s' "$INPUT" | jq -r '.confidence // 0' 2>/dev/null)"
DETS="$(printf '%s' "$INPUT" | jq -r '.deterministic_matches // []' 2>/dev/null)"

# Leer política YAML (python3 + yaml; sin dependencias)
POLICY_JSON="$(python3 -c "
import yaml, json
p = yaml.safe_load(open('$POLICY'))
print(json.dumps(p))
" 2>/dev/null)"
ALLOW_BELOW="$(printf '%s' "$POLICY_JSON" | jq -r '.allow_below // 0.70' 2>/dev/null)"
DEST_CFG="$(printf '%s' "$POLICY_JSON" | jq -c '.destinations.'"$DEST"' // {}' 2>/dev/null)"

# Hard block rules: deterministas SIEMPRE bloquean en N1
HARD_BLOCK=false
if [[ "$DEST" == "n1" ]]; then
  for rule in $(printf '%s' "$POLICY_JSON" | jq -r '.hard_block_rules[]?' 2>/dev/null); do
    if printf '%s' "$DETS" | grep -q "$rule"; then
      HARD_BLOCK=true
    fi
  done
fi

# Decisión
ACTION="ALLOW"
REASON="below_threshold"
if [[ "$HARD_BLOCK" == "true" ]]; then
  ACTION="BLOCK"; REASON="hard_block_deterministic"
elif [[ "$LABEL" == "confidential" ]]; then
  CB="$(printf '%s' "$DEST_CFG" | jq -r '.confidential_block_below // 0.90' 2>/dev/null)"
  if python3 -c "import sys; sys.exit(0 if float('$CONF') >= float('$CB') else 1)" 2>/dev/null; then
    ACTION="BLOCK"; REASON="confidential_high_confidence"
  else
    WARN_ABOVE="$(printf '%s' "$DEST_CFG" | jq -r '.warn_above // 0.70' 2>/dev/null)"
    if python3 -c "import sys; sys.exit(0 if float('$CONF') >= float('$WARN_ABOVE') else 1)" 2>/dev/null; then
      ACTION="WARN"; REASON="confidential_medium_confidence"
    else
      ACTION="ALLOW"; REASON="below_threshold"
    fi
  fi
elif [[ "$LABEL" == "ambiguous" ]]; then
  AMB_ACT="$(printf '%s' "$DEST_CFG" | jq -r '.ambiguous_action // "WARN"' 2>/dev/null)"
  ACTION="$AMB_ACT"; REASON="ambiguous"
fi

printf '{"action":"%s","reason":"%s","label":"%s","confidence":%s,"hard_block":%s}\n' \
  "$ACTION" "$REASON" "$LABEL" "${CONF:-0}" "${HARD_BLOCK}"

if [[ "$ACTION" == "BLOCK" ]]; then
  exit 1
fi
exit 0
