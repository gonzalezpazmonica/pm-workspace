#!/usr/bin/env bash
# labs-preregister.sh — Preregistro de hipotesis en Savia Labs
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABS_DIR="$ROOT/labs"
HYPOTHESES_DIR="$LABS_DIR/hypotheses"

TITLE=""; LINE=""; METHOD=""; METRIC=""; SUCCESS=""; FAILURE=""
SAMPLE=""; BUDGET_TOKENS=""; BUDGET_HOURS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    --line) LINE="$2"; shift 2 ;;
    --method) METHOD="$2"; shift 2 ;;
    --metric) METRIC="$2"; shift 2 ;;
    --success) SUCCESS="$2"; shift 2 ;;
    --failure) FAILURE="$2"; shift 2 ;;
    --sample) SAMPLE="$2"; shift 2 ;;
    --budget-tokens) BUDGET_TOKENS="$2"; shift 2 ;;
    --budget-hours) BUDGET_HOURS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$TITLE" || -z "$LINE" || -z "$METHOD" || -z "$METRIC" || -z "$SUCCESS" || -z "$FAILURE" || -z "$SAMPLE" ]]; then
  echo "ERROR: Missing required fields"
  echo "Required: --title, --line, --method, --metric, --success, --failure, --sample"
  exit 1
fi

if [[ ! "$LINE" =~ ^L[1-6]$ ]]; then
  echo "ERROR: --line must be L1-L6"
  exit 1
fi

mkdir -p "$HYPOTHESES_DIR"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | head -c 50)
VAULT_REV=$(cd "$LABS_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")

cat > "$HYPOTHESES_DIR/$SLUG.md" << REGEOF
---
entity: {type: hypothesis, id: $SLUG}
title: $TITLE
line: $LINE
method: $METHOD
metric: $METRIC
success_criterion: $SUCCESS
failure_criterion: $FAILURE
sample_size: $SAMPLE
status: preregistered
preregistered_at: $TS
model_version: pending
vault_revision: $VAULT_REV
budget_tokens: ${BUDGET_TOKENS:-0}
budget_hours: ${BUDGET_HOURS:-0}
tags: [hypothesis, $LINE, preregistered]
confidentiality: N2
---

# $TITLE

**Linea:** $LINE
**Preregistrado:** $TS

## Metodo
$METHOD

## Metrica
$METRIC

## Criterio de exito
$SUCCESS

## Criterio de fracaso
$FAILURE

## Muestra planificada
$SAMPLE

## Presupuesto
- Tokens: ${BUDGET_TOKENS:-no declarado}
- Horas: ${BUDGET_HOURS:-no declarado}
REGEOF

NOTEBOOK="$LABS_DIR/notebook/$(date +%Y%m%d)-preregistration.md"
if [[ ! -f "$NOTEBOOK" ]]; then
  echo "# $(date +%Y-%m-%d) — Registro de Preregistros" > "$NOTEBOOK"
fi
echo "- [$TS] **$LINE**: $TITLE (sample: $SAMPLE)" >> "$NOTEBOOK"

cd "$LABS_DIR"
git add -A && git commit -m "preregister: $LINE — $TITLE" 2>/dev/null || true

echo "Preregistered: $SLUG"
echo "File: hypotheses/$SLUG.md"
