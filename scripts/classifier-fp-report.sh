#!/usr/bin/env bash
# classifier-fp-report.sh — SE-314 S5 (AC-S5.4): reporte de falsos positivos.
#
# Lee output/telemetry-events.jsonl y output/data-sovereignty-audit.jsonl,
# agrega bloqueos del clasificador por mes y genera un informe markdown en
# output/classifier-fp-report-{YYYY-MM}.md. También emite el evento
# classifier.false_positive cuando un bloqueo fue corregido/revertido
# (marcador manual: el operador registra el override en la audit log).
#
# Uso: classifier-fp-report.sh [--month YYYY-MM]
# Exit: 0 ok, 1 sin datos, 2 usage.
set -uo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TELEMETRY="$REPO_ROOT/output/telemetry-events.jsonl"
AUDIT="$REPO_ROOT/output/data-sovereignty-audit.jsonl"
EMIT="$REPO_ROOT/scripts/otel-emit.sh"
MONTH="${1:-$(date -u +%Y-%m)}"
if [[ "$MONTH" == "--month" ]]; then
  MONTH="$2"
fi

OUT="$REPO_ROOT/output/classifier-fp-report-${MONTH}.md"
mkdir -p "$(dirname "$OUT")" 2>/dev/null || true

# ── Agregar eventos classifier.* del mes ─────────────────────────────────────
BLOCKS=0; VERDICTS=0; WARNINGS=0
FP_CANDIDATES=""
if [[ -f "$TELEMETRY" ]]; then
  # Extraer bloqueos y veredictos del clasificador en el mes
  BLOCKS=$(jq -r 'select(.event == "classifier.block") | .ts' "$TELEMETRY" 2>/dev/null | grep -c "^${MONTH}" || echo 0)
  VERDICTS=$(jq -r 'select(.event == "classifier.verdict") | .ts' "$TELEMETRY" 2>/dev/null | grep -c "^${MONTH}" || echo 0)
  WARNINGS=$(jq -r 'select(.event == "classifier.verdict" and .action == "WARN") | .ts' "$TELEMETRY" 2>/dev/null | grep -c "^${MONTH}" || echo 0)
fi

# Falsos positivos corregidos: registros en audit con override/permiso del operador
FP_CORRECTED=0
if [[ -f "$AUDIT" ]]; then
  FP_CORRECTED=$(grep -iE "override|manual_allow|false_positive" "$AUDIT" 2>/dev/null | grep -c "$MONTH" || echo 0)
fi

cat > "$OUT" << MDEOF
# Reporte de Falsos Positivos del Clasificador — ${MONTH}

**Generado:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Métricas (SE-314 S9)

| Métrica | Valor |
|---|---|
| Bloqueos del clasificador (classifier.block) | ${BLOCKS} |
| Veredictos emitidos (classifier.verdict) | ${VERDICTS} |
| Warnings en N1 (permitidos) | ${WARNINGS} |
| FPs corregidos / overrides registrados | ${FP_CORRECTED} |

## Interpretación

- **Tasa de CONFIDENTIAL sobre contenido técnico**: objetivo < 2%.
  Ver corpus de regresión: \`tests/evals/classifier-corpus.json\`
  (runner: \`scripts/classifier-corpus-run.sh\`).
- **Umbrales**: \`config/sovereignty-thresholds.yaml\`.
- Si un bloqueo fue incorrecto, registrar el override en
  \`output/data-sovereignty-audit.jsonl\` con la palabra \`false_positive\`;
  el siguiente reporte lo contará como FP corregido.
MDEOF

# ── Emitir evento de FP (opcional: tras registrar override) ──────────────────
# SAVIA_CLASSIFIER_FP=1 indica que este reporte se genera tras una corrección.
if [[ "${SAVIA_CLASSIFIER_FP:-0}" == "1" ]] && [[ -x "$EMIT" ]]; then
  "$EMIT" classifier.false_positive agent_name=operator month="$MONTH" \
    corrected="$FP_CORRECTED" retention_days=180 >/dev/null 2>&1 || true
fi

echo "reporte: $OUT"
[[ -f "$OUT" ]]
