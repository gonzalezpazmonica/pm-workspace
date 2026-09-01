#!/usr/bin/env bash
# acceptance-cost.sh — SE-360: costo por cambio aceptado (CLI wrapper).
# set -uo pipefail
#
# Envuelve acceptance-cost-agg.py para generar el informe markdown/JSON del
# costo de aceptación de cambios, descompuesto por etapa.
#
# Uso:
#   acceptance-cost.sh [--days 30] [--format markdown|json] [--runs FILE] [--audit FILE]
#
# Salida por defecto: output/research/acceptance-cost-{date}.md
# Ref: SE-360 — costo por cambio aceptado
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAYS=30
FORMAT="markdown"
RUNS="$ROOT/data/agent-runs-ledger.jsonl"
AUDIT="$ROOT/data/audit/actions.jsonl"

while [[ $# -gt 0 ]]; do case "$1" in
  --days) DAYS="$2"; shift 2 ;;
  --format) FORMAT="$2"; shift 2 ;;
  --runs) RUNS="$2"; shift 2 ;;
  --audit) AUDIT="$2"; shift 2 ;;
  *) shift ;;
esac; done

OUT_DIR="$ROOT/output/research"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/acceptance-cost-$(date +%Y%m%d).md"

if [[ "$FORMAT" == "json" ]]; then
  python3 "$ROOT/scripts/acceptance-cost-agg.py" --runs "$RUNS" --audit "$AUDIT" --days "$DAYS" --json
  exit 0
fi

# markdown
python3 "$ROOT/scripts/acceptance-cost-agg.py" --runs "$RUNS" --audit "$AUDIT" --days "$DAYS" > "$OUT_FILE"
echo "Informe acceptance-cost escrito: $OUT_FILE"
echo "---"
cat "$OUT_FILE"
