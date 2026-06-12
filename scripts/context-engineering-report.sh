#!/usr/bin/env bash
set -uo pipefail
# context-engineering-report.sh — SE-221 Slice 4 — Weekly report generator
# Genera reporte de impacto de SE-221 desde audit logs + audience graph.
#
# Spec: docs/propuestas/SE-221-inverted-security-patterns-as-context-engineering.md (AC-18)
#
# Uso:
#   scripts/context-engineering-report.sh             # genera report y muestra path
#   scripts/context-engineering-report.sh --stdout    # imprime tambien a stdout
#   scripts/context-engineering-report.sh --since=YYYY-MM-DD

STDOUT=0
SINCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stdout) STDOUT=1; shift ;;
    --since=*) SINCE="${1#*=}"; shift ;;
    --since) SINCE="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SAVIA_WORKSPACE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OUTPUT_DIR="$WORKSPACE/output"
mkdir -p "$OUTPUT_DIR"

# Output filename con fecha
DATE_TAG=$(date +%Y%m%d 2>/dev/null || echo "unknown")
REPORT="$OUTPUT_DIR/${DATE_TAG}-context-engineering-report.md"

DROP_AUDIT="$OUTPUT_DIR/context-drop-audit.jsonl"
AUDIENCE_GRAPH="$OUTPUT_DIR/context-audience-graph.json"
AUDIENCE_CROSS="$OUTPUT_DIR/context-audience-cross.tsv"
DROP_METRICS="$SCRIPT_DIR/context-drop-metrics.sh"

# Recolectar metricas
DROP_JSON='{}'
if [[ -f "$DROP_AUDIT" ]] && [[ -x "$DROP_METRICS" ]]; then
  if [[ -n "$SINCE" ]]; then
    DROP_JSON=$(bash "$DROP_METRICS" --json --since="$SINCE" --log "$DROP_AUDIT" 2>/dev/null || echo '{}')
  else
    DROP_JSON=$(bash "$DROP_METRICS" --json --log "$DROP_AUDIT" 2>/dev/null || echo '{}')
  fi
fi

# Audience stats
AUDIENCE_STATS='{}'
if [[ -f "$AUDIENCE_GRAPH" ]]; then
  AUDIENCE_STATS=$(jq '{
    n_files_scanned,
    n_files_with_audience,
    n_agents_referenced,
    top_agents: (.agents | to_entries | sort_by(-(.value | length)) | .[0:5] | map({agent: .key, n_files: (.value | length)}))
  }' "$AUDIENCE_GRAPH" 2>/dev/null || echo '{}')
fi

# Top cross-concept pairs
TOP_PAIRS=""
if [[ -f "$AUDIENCE_CROSS" ]]; then
  TOP_PAIRS=$(tail -n +2 "$AUDIENCE_CROSS" 2>/dev/null | sort -t $'\t' -k4 -n -r | head -10 || echo "")
fi

# Origin tag coverage (best-effort): cuenta lineas '---origin' en logs recientes
ORIGIN_COVERAGE=0
if compgen -G "$OUTPUT_DIR/session*.log" > /dev/null 2>&1; then
  ORIGIN_COVERAGE=$(grep -h "^---origin$" "$OUTPUT_DIR"/session*.log 2>/dev/null | wc -l | tr -d ' ')
fi

# Construir reporte
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
N_TOTAL=$(echo "$DROP_JSON" | jq -r '.n_total // 0')
N_STUBS=$(echo "$DROP_JSON" | jq -r '.n_stubs // 0')
N_KEEPS=$(echo "$DROP_JSON" | jq -r '.n_keeps // 0')
N_DROPS=$(echo "$DROP_JSON" | jq -r '.n_drops // 0')
TOKENS_SAVED=$(echo "$DROP_JSON" | jq -r '.total_tokens_saved // 0')
PCT_SAVED=$(echo "$DROP_JSON" | jq -r '.pct_saved // 0')

N_FILES_SCANNED=$(echo "$AUDIENCE_STATS" | jq -r '.n_files_scanned // 0')
N_FILES_WITH_AUDIENCE=$(echo "$AUDIENCE_STATS" | jq -r '.n_files_with_audience // 0')
N_AGENTS_REFERENCED=$(echo "$AUDIENCE_STATS" | jq -r '.n_agents_referenced // 0')

{
  echo "# Context Engineering Report"
  echo ""
  echo "> Spec: SE-221 — Patrones adversariales invertidos como ingenieria de contexto"
  echo "> Generated: $TS"
  if [[ -n "$SINCE" ]]; then echo "> Since: $SINCE"; fi
  echo ""
  echo "## Slice 2 — Drop-After-Use"
  echo ""
  echo "| Metrica | Valor |"
  echo "|---|---|"
  echo "| Total decisiones | $N_TOTAL |"
  echo "| STUB | $N_STUBS |"
  echo "| KEEP | $N_KEEPS |"
  echo "| DROP | $N_DROPS |"
  echo "| Tokens ahorrados estimados | $TOKENS_SAVED |"
  echo "| Pct ops reducidas | ${PCT_SAVED}% |"
  echo ""
  echo "Top tools y tiers (segun audit):"
  echo ""
  echo '```json'
  echo "$DROP_JSON" | jq '{by_tool, by_tier}' 2>/dev/null || echo "(sin datos)"
  echo '```'
  echo ""
  echo "## Slice 3 — Audience Graph"
  echo ""
  echo "| Metrica | Valor |"
  echo "|---|---|"
  echo "| Ficheros escaneados | $N_FILES_SCANNED |"
  echo "| Ficheros con audience explicita | $N_FILES_WITH_AUDIENCE |"
  echo "| Agentes referenciados | $N_AGENTS_REFERENCED |"
  echo ""
  echo "Top agents por numero de ficheros target:"
  echo ""
  echo '```json'
  echo "$AUDIENCE_STATS" | jq '.top_agents' 2>/dev/null || echo "(sin datos)"
  echo '```'
  echo ""
  echo "## Top pares cross-concept (audience compartida)"
  echo ""
  if [[ -n "$TOP_PAIRS" ]]; then
    echo "| path_a | path_b | shared | count |"
    echo "|---|---|---|---|"
    echo "$TOP_PAIRS" | awk -F'\t' '{printf "| %s | %s | %s | %s |\n", $1, $2, $3, $4}'
  else
    echo "(sin datos — ejecutar: python3 scripts/context-audience-graph.py)"
  fi
  echo ""
  echo "## Slice 1 — Origin Tag Coverage"
  echo ""
  echo "Bloques \`---origin\` detectados en session logs: $ORIGIN_COVERAGE"
  echo ""
  echo "## Drift detector"
  echo ""
  echo "Ficheros con audience cuyo tier ha cambiado: (placeholder, requiere baseline)"
  echo ""
  echo "## Refs"
  echo ""
  echo "- Spec: docs/propuestas/SE-221-*.md"
  echo "- Audit logs: $DROP_AUDIT"
  echo "- Audience graph: $AUDIENCE_GRAPH"
  echo "- Audience cross: $AUDIENCE_CROSS"
} > "$REPORT"

if [[ "$STDOUT" -eq 1 ]]; then
  cat "$REPORT"
fi

echo "Report generated: $REPORT" >&2
exit 0
