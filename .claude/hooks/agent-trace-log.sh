#!/bin/bash
set -uo pipefail
# ────────────────────────────────────────────────────────────────────────────
# PostToolUse Hook: agent-trace-log.sh
# Registra la ejecución de agentes (Task tool) en trazas JSONL
# Includes per-agent token budget metering (SPEC-AGENT-METERING)
# ────────────────────────────────────────────────────────────────────────────

set -e

# Only trigger for Task tool (subagent invocation)
if [[ "$TOOL_NAME" != "Task" ]]; then
    exit 0
fi

# Extraer variables de entorno y TOOL_INPUT
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
TRACES_DIR="$PROJECT_DIR/projects/$CLAUDE_PROJECT_NAME/traces"

# Crear directorio si no existe
mkdir -p "$TRACES_DIR" 2>/dev/null || true

# Extraer datos de TOOL_INPUT (JSON)
# Formato esperado: {"type": "task", "agent": "agente-name", "description": "..."}
AGENT_NAME=$(echo "$TOOL_INPUT" | grep -o '"agent":\s*"[^"]*"' | cut -d'"' -f4 || echo "unknown")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Estimar tokens (aproximado basado en longitud)
INPUT_LENGTH=${#TOOL_INPUT}
OUTPUT_LENGTH=${#TOOL_OUTPUT:-0}
TOKENS_IN=$((INPUT_LENGTH / 4))
TOKENS_OUT=$((OUTPUT_LENGTH / 4))

# Calcular duración (en segundos, convertir a ms)
DURATION_S=${TOOL_DURATION:-0}
DURATION_MS=$((DURATION_S * 1000))

# Determinar outcome
OUTCOME="success"
if [[ "$TOOL_RESULT_STATUS" == "error" ]] || [[ $DURATION_S -gt 120 ]]; then
    OUTCOME="failure"
elif [[ "$TOOL_RESULT_STATUS" == "partial" ]]; then
    OUTCOME="partial"
fi

# ── Budget metering (SPEC-AGENT-METERING) ────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOKEN_BUDGET=$(bash "$SCRIPT_DIR/scripts/agent-budget-lookup.sh" "$AGENT_NAME" 2>/dev/null || echo "0")
TOKEN_BUDGET=${TOKEN_BUDGET:-0}

TOTAL_TOKENS=$((TOKENS_IN + TOKENS_OUT))
BUDGET_EXCEEDED="false"
if [[ "$TOKEN_BUDGET" -gt 0 ]] && [[ "$TOTAL_TOKENS" -gt "$TOKEN_BUDGET" ]]; then
    BUDGET_EXCEEDED="true"
fi

# Construir línea JSONL
TRACE_LINE=$(cat <<EOF
{"timestamp":"$TIMESTAMP","agent":"$AGENT_NAME","command":"task","tokens_in":$TOKENS_IN,"tokens_out":$TOKENS_OUT,"token_budget":$TOKEN_BUDGET,"budget_exceeded":$BUDGET_EXCEEDED,"duration_ms":$DURATION_MS,"files_modified":[],"outcome":"$OUTCOME","scope_violations":[]}
EOF
)

# Appendear a fichero de trazas (async, silent)
echo "$TRACE_LINE" >> "$TRACES_DIR/agent-traces.jsonl" 2>/dev/null || true

# ── Budget alert (only when exceeded and budget > 0) ─────────────────────
if [[ "$BUDGET_EXCEEDED" == "true" ]]; then
    OVERAGE=$((TOTAL_TOKENS - TOKEN_BUDGET))
    OVERAGE_PCT=$(( (OVERAGE * 100) / TOKEN_BUDGET ))
    ALERT_LINE="{\"timestamp\":\"$TIMESTAMP\",\"agent\":\"$AGENT_NAME\",\"tokens_in\":$TOKENS_IN,\"tokens_out\":$TOKENS_OUT,\"token_budget\":$TOKEN_BUDGET,\"total\":$TOTAL_TOKENS,\"overage\":$OVERAGE,\"overage_pct\":$OVERAGE_PCT}"
    echo "$ALERT_LINE" >> "$TRACES_DIR/budget-alerts.jsonl" 2>/dev/null || true
fi

exit 0
