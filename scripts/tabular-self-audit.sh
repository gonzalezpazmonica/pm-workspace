#!/usr/bin/env bash
set -euo pipefail
# tabular-self-audit.sh — Post-turn: verify tabular tools were used when needed
# SE-296 Capa 4: escanea el turno y emite WARN/BLOCK si se ignoraron

AUDIT_LOG="${SAVIA_AUDIT_LOG:-$HOME/.savia/tabular-audit.jsonl}"
TURN_LOG="${1:-/dev/stdin}"
WARNINGS=0
BYPASS_COUNT=0

# Read prior bypass count
if [[ -f "$AUDIT_LOG" ]]; then
  BYPASS_COUNT=$(grep -c '"verdict":"BYPASS"' "$AUDIT_LOG" 2>/dev/null | tr -d '\n' || true)
fi
  [[ -z "$BYPASS_COUNT" ]] && BYPASS_COUNT=0

# Detect tabular data in turn
TABULAR_LINES=$(grep -cE '^\s*\|.+\||^[^,|]+(,[^,|]+)+$|^\w+,[\d.,]+' "$TURN_LOG" 2>/dev/null | tr -d '\n' || true)
[[ -z "$TABULAR_LINES" ]] && TABULAR_LINES=0

# Check if profiler was used
PROFILER_USED=$(grep -c "tabular-profile.py\|tabular_query\|tabular-summarize" "$TURN_LOG" 2>/dev/null | tr -d '\n' || true)
[[ -z "$PROFILER_USED" ]] && PROFILER_USED=0

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [[ "$TABULAR_LINES" -ge 5 && "$PROFILER_USED" -eq 0 ]]; then
  WARNINGS=1
  BYPASS_COUNT=$((BYPASS_COUNT + 1))
  
  echo "{\"timestamp\":\"$TIMESTAMP\",\"verdict\":\"BYPASS\",\"tabular_lines\":$TABULAR_LINES,\"profiler_used\":false,\"bypass_count\":$BYPASS_COUNT}" >> "$AUDIT_LOG"
  
  if [[ "$BYPASS_COUNT" -ge 3 ]]; then
    echo "BLOCK [tabular-self-audit]: 3+ turnos con datos tabulares sin usar tabular-profile.py"
    echo "  Accion requerida: usa tabular_query o tabular-profile.py para analizar datos tabulares"
    echo "  Bypass count: $BYPASS_COUNT"
    exit 1
  else
    echo "WARN [tabular-self-audit]: datos tabulares detectados sin perfil estadistico"
    echo "  Lineas tabulares: $TABULAR_LINES"
    echo "  Profiler usado: NO"
    echo "  Bypass count: $BYPASS_COUNT (BLOCK a los 3)"
    exit 0
  fi
else
  echo "{\"timestamp\":\"$TIMESTAMP\",\"verdict\":\"OK\",\"tabular_lines\":$TABULAR_LINES,\"profiler_used\":$([[ $PROFILER_USED -gt 0 ]] && echo true || echo false)}" >> "$AUDIT_LOG"
  exit 0
fi
