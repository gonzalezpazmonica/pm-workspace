#!/usr/bin/env bash
set -uo pipefail
# kg-quality-report.sh — Weekly KG health metrics

AUDIT_DIR="${SAVIA_AUDIT_DIR:-$HOME/.savia/kg-audit}"
WEEK=$(date +%Y-W%V)
REPORT="$AUDIT_DIR/report-$WEEK.json"

mkdir -p "$AUDIT_DIR"

total_docs=$(find "$AUDIT_DIR" -name "doc-*.json" 2>/dev/null | wc -l)
docs_with_kg=$(grep -l '"entity_count":[1-9]' "$AUDIT_DIR"/doc-*.json 2>/dev/null | wc -l)
total_entities=$(grep -oh '"entity_count":[0-9]*' "$AUDIT_DIR"/doc-*.json 2>/dev/null | grep -o '[0-9]*' | paste -sd+ | bc 2>/dev/null || echo 0)
proposed=$(grep -c '"status":"proposed"' "$AUDIT_DIR"/doc-*.json 2>/dev/null || echo 0)
rejected=$(grep -c '"status":"rejected"' "$AUDIT_DIR"/doc-*.json 2>/dev/null || echo 0)

coverage_pct=0
[[ $total_docs -gt 0 ]] && coverage_pct=$((docs_with_kg * 100 / total_docs))

cat > "$REPORT" << JSONREPORT
{
  "week": "$WEEK",
  "total_documents": $total_docs,
  "documents_with_kg": $docs_with_kg,
  "coverage_pct": $coverage_pct,
  "total_entities": $total_entities,
  "proposed": $proposed,
  "rejected": $rejected,
  "status": "$([[ $coverage_pct -ge 80 ]] && echo 'OK' || ([[ $coverage_pct -ge 50 ]] && echo 'WARN' || echo 'BLOCK'))"
}
JSONREPORT

echo "KG Quality Report — Week $WEEK"
echo "  Documents: $total_docs total, $docs_with_kg with KG ($coverage_pct%)"
echo "  Entities: $total_entities total, $proposed proposed, $rejected rejected"
echo "  Report: $REPORT"
