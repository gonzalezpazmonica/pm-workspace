#!/usr/bin/env bash
# agent-manifest-batch-export.sh — SPEC-SE-004: Exporta todos los agentes a todos los frameworks
set -uo pipefail
#
# Itera sobre todos los agentes en .opencode/agents/ y genera manifiestos
# en todos los formatos soportados (o uno específico).
# Genera también compatibility-matrix.json.
#
# Usage:
#   agent-manifest-batch-export.sh [--format FORMAT] [--output-dir DIR]
#
# Args:
#   --format FORMAT   Exportar solo a este formato (default: all)
#   --output-dir DIR  Base dir de salida (default: .claude/enterprise/adapters)
#
# Output:
#   .claude/enterprise/adapters/{format}/*.yaml|json
#   .claude/enterprise/adapters/compatibility-matrix.json
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-004-agent-framework-interop.md

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

FORMAT_FILTER="all"
OUTPUT_BASE="${ROOT_DIR}/.claude/enterprise/adapters"

ALL_FORMATS="msagent langgraph semantic-kernel pydantic-ai openai-agents"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)     FORMAT_FILTER="$2"; shift 2 ;;
    --output-dir) OUTPUT_BASE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
      exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

AGENTS_DIR="${ROOT_DIR}/.opencode/agents"
EXPORT_SCRIPT="${SCRIPT_DIR}/agent-manifest-export.sh"

if [[ ! -d "$AGENTS_DIR" ]]; then
  echo "ERROR: agents directory not found: $AGENTS_DIR" >&2; exit 3
fi
if [[ ! -f "$EXPORT_SCRIPT" ]]; then
  echo "ERROR: agent-manifest-export.sh not found" >&2; exit 3
fi

# Determinar formatos a exportar
if [[ "$FORMAT_FILTER" == "all" ]]; then
  FORMATS="$ALL_FORMATS"
else
  FORMATS="$FORMAT_FILTER"
fi

# ── Iterar agentes ────────────────────────────────────────────────────────────

TOTAL=0
EXPORTED=0
ERRORS=0
declare -A COMPAT_MAP  # agent_name → "format1:true format2:true ..."

echo "Exportando agentes desde $AGENTS_DIR ..."
echo "Formatos: $FORMATS"
echo ""

for AGENT_FILE in "${AGENTS_DIR}"/*.md; do
  [[ -f "$AGENT_FILE" ]] || continue
  AGENT_NAME=$(basename "$AGENT_FILE" .md)
  TOTAL=$((TOTAL + 1))

  declare -A agent_compat
  for fmt in $FORMATS; do
    agent_compat[$fmt]="false"
  done

  for fmt in $FORMATS; do
    if bash "$EXPORT_SCRIPT" \
        --agent "$AGENT_NAME" \
        --format "$fmt" \
        --output-dir "$OUTPUT_BASE" \
        >/dev/null 2>&1; then
      agent_compat[$fmt]="true"
      EXPORTED=$((EXPORTED + 1))
    else
      ERRORS=$((ERRORS + 1))
    fi
  done

  # Guardar para la matriz
  COMPAT_MAP["$AGENT_NAME"]=""
  for fmt in $FORMATS; do
    COMPAT_MAP["$AGENT_NAME"]+="${fmt}:${agent_compat[$fmt]} "
  done
  unset agent_compat
done

echo "Agentes procesados: $TOTAL"
echo "Exports exitosos:   $EXPORTED"
echo "Errores:            $ERRORS"
echo ""

# ── Generar compatibility-matrix.json ─────────────────────────────────────────

MATRIX_FILE="${OUTPUT_BASE}/compatibility-matrix.json"
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

{
  echo "{"
  echo "  \"_spec\": \"SE-004\","
  echo "  \"generated_at\": \"$GENERATED_AT\","
  echo "  \"formats\": [$(echo "$ALL_FORMATS" | tr ' ' '\n' | sed 's/.*/"&"/' | paste -sd,)],"
  echo "  \"agents\": {"
  FIRST_AGENT=1
  for AGENT_NAME in "${!COMPAT_MAP[@]}"; do
    [[ $FIRST_AGENT -eq 0 ]] && echo ","
    FIRST_AGENT=0
    echo -n "    \"$AGENT_NAME\": {"
    FIRST_FMT=1
    for fmt in $ALL_FORMATS; do
      [[ $FIRST_FMT -eq 0 ]] && echo -n ", "
      FIRST_FMT=0
      # Buscar valor en la entrada del agente
      COMPAT_ENTRY="${COMPAT_MAP[$AGENT_NAME]}"
      if echo "$COMPAT_ENTRY" | grep -q "${fmt}:true"; then
        echo -n "\"$fmt\": true"
      else
        echo -n "\"$fmt\": false"
      fi
    done
    echo -n "}"
  done
  echo ""
  echo "  }"
  echo "}"
} > "$MATRIX_FILE"

echo "Compatibility matrix: $MATRIX_FILE"
