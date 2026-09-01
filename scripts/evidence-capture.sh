#!/usr/bin/env bash
# evidence-capture.sh — SE-364: bucle de evidencia (wrapper CLI).
# set -uo pipefail
#
# Envuelve evidence-capture.py: captura intervenciones humanas desde ledgers
# locales y genera evals discriminantes para el runner existente (SPEC-151).
#
# Uso:
#   evidence-capture.sh [--audit data/audit/actions.jsonl] [--corpus data/evidence-corpus]
#                       [--to-evals] [--output output/evals.json]
# Ref: SE-364 — bucle de evidencia
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT="$ROOT/data/audit/actions.jsonl"
CORPUS="$ROOT/data/evidence-corpus"
OUTPUT="$ROOT/output/evals.json"
TO_EVALS=false

while [[ $# -gt 0 ]]; do case "$1" in
  --audit) AUDIT="$2"; shift 2 ;;
  --corpus) CORPUS="$2"; shift 2 ;;
  --to-evals) TO_EVALS=true; shift ;;
  --output) OUTPUT="$2"; shift 2 ;;
  *) shift ;;
esac; done

if $TO_EVALS; then
  python3 "$ROOT/scripts/evidence-capture.py" --to-evals --corpus "$CORPUS" --output "$OUTPUT"
else
  python3 "$ROOT/scripts/evidence-capture.py" --audit "$AUDIT" --corpus "$CORPUS"
fi
