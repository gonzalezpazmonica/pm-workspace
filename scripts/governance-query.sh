#!/usr/bin/env bash
# governance-query.sh — SE-363: consulta la capa de registro de gobernanza.
# set -uo pipefail
#
# Consulta data/governance/criterios.jsonl (capa estructurada debajo de
# CRITERIO.md). El Markdown es la vista; el JSONL es el registro consultable.
#
# Uso:
#   governance-query.sh [--registry data/governance/criterios.jsonl] [--status ACTIVE]
#                       [--approved-by X] [--json]
# Ref: SE-363 — registros-no-archivos
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$ROOT/data/governance/criterios.jsonl"
STATUS=""
APPROVED_BY=""
JSON=false

while [[ $# -gt 0 ]]; do case "$1" in
  --registry) REGISTRY="$2"; shift 2 ;;
  --status) STATUS="$2"; shift 2 ;;
  --approved-by) APPROVED_BY="$2"; shift 2 ;;
  --json) JSON=true; shift ;;
  *) shift ;;
esac; done

ARGS=(--registry "$REGISTRY")
[[ -n "$STATUS" ]] && ARGS+=(--status "$STATUS")
[[ -n "$APPROVED_BY" ]] && ARGS+=(--approved-by "$APPROVED_BY")
$JSON && ARGS+=(--json)

python3 "$ROOT/scripts/governance-sync.py" query "${ARGS[@]}"
