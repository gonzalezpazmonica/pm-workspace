#!/usr/bin/env bash
set -uo pipefail
# savia-rag-sync.sh — Disparador programado de Savia RAG (SE-410 P3/P7).
# Sync incremental de todas las cúpulas con rag.enabled y comprobación de SLO.
# Cron sugerido: cada 6 h  → savia-rag-sync.sh
#                semanal   → savia-rag-sync.sh --rebuild   (checkpoint)
# Exit: 0 ok · 1 fallo de sync o de configuración · 2 alerta de SLO

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULTS_DIR="$ROOT/projects/savia-vaults"
DOMES_FILE="${SAVIA_RAG_DOMES_FILE:-$VAULTS_DIR/savia-vaults.domes.json}"
CLI="${SAVIA_RAG_CLI:-node $VAULTS_DIR/dist/cli/index.js}"
REBUILD=""

usage() {
  echo "Usage: $(basename "$0") [--rebuild]"
  echo "  --rebuild   re-embebe todo (checkpoint semanal, P8)"
  echo "Env: SAVIA_RAG_DOMES_FILE, SAVIA_RAG_CLI, SAVIA_RAG_HOME"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rebuild) REBUILD="--rebuild"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! -f "$DOMES_FILE" ]]; then
  echo "savia-rag-sync: registry de cúpulas no encontrado: $DOMES_FILE" >&2
  exit 1
fi

rc=0
# shellcheck disable=SC2086  # CLI puede ser "node <ruta>"
$CLI rag sync --domes-file "$DOMES_FILE" --all $REBUILD
sync_rc=$?
if [[ $sync_rc -eq 3 ]]; then
  echo "savia-rag-sync: sync en curso en otro proceso; se omite esta pasada"
elif [[ $sync_rc -ne 0 ]]; then
  echo "savia-rag-sync: sync falló (exit $sync_rc)" >&2
  rc=1
fi

# shellcheck disable=SC2086
$CLI rag status --domes-file "$DOMES_FILE" --check
status_rc=$?
if [[ $status_rc -eq 2 && $rc -eq 0 ]]; then
  rc=2
elif [[ $status_rc -ne 0 && $status_rc -ne 2 ]]; then
  rc=1
fi
exit $rc
