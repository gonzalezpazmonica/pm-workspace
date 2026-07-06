#!/usr/bin/env bash
# scripts/relacion-capture.sh — SE-255 Slice 3
# Captura automatica de entradas en el libro de la relacion.
# Tipos: override, error_reconocido, acierto_verificado, no_se_declarado,
#        enmienda_criterio, feedback_explicito.
#
# Uso: bash scripts/relacion-capture.sh <tipo> <texto> [--claim-id ID] [--contexto FILE]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
LEDGER="$ROOT/data/relacion/ledger.jsonl"
TIPO="${1:-}"
TEXTO="${2:-}"
CLAIM_ID=""
CONTEXTO=""

shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --claim-id) CLAIM_ID="$2"; shift 2 ;;
    --contexto) CONTEXTO="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$TIPO" || -z "$TEXTO" ]]; then
  echo "Usage: $0 <tipo> <texto> [--claim-id ID] [--contexto FILE]"
  echo "Tipos: override, error_reconocido, acierto_verificado, no_se_declarado, enmienda_criterio, feedback_explicito"
  exit 2
fi

# Validar tipo
VALID_TYPES="override error_reconocido acierto_verificado no_se_declarado enmienda_criterio feedback_explicito"
if ! echo "$VALID_TYPES" | grep -qw "$TIPO"; then
  echo "ERROR: tipo invalido '$TIPO'. Validos: $VALID_TYPES" >&2
  exit 1
fi

mkdir -p "$(dirname "$LEDGER")"

# Leer hash anterior para encadenamiento
PREV_HASH="null"
if [[ -f "$LEDGER" ]]; then
  LAST_LINE=$(tail -1 "$LEDGER" 2>/dev/null || echo "")
  if [[ -n "$LAST_LINE" ]]; then
    PREV_HASH=$(echo "$LAST_LINE" | sha256sum | awk '{print $1}')
  fi
fi

# Generar entry_id unico
ENTRY_ID="${TIPO}-$(date +%Y%m%d-%H%M%S)-$$"

# Construir entrada JSON
python3 -c "
import json, sys
entry = {
    'entry_id': '$ENTRY_ID',
    'tipo': '$TIPO',
    'texto': '''$TEXTO''',
    'ts': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'provenance': 'auto_capture',
    'hash_prev': '$PREV_HASH',
}
if '$CLAIM_ID':
    entry['claim_id'] = '$CLAIM_ID'
if '$CONTEXTO':
    entry['contexto'] = open('$CONTEXTO').read()[:500] if '$CONTEXTO' else ''
print(json.dumps(entry, ensure_ascii=False))
" >> "$LEDGER"

# Verificar append-only (la ultima linea debe contener este entry_id)
if ! tail -1 "$LEDGER" | grep -q "$ENTRY_ID"; then
  echo "ERROR: ledger append verification failed" >&2
  exit 1
fi

echo "Capturado: $ENTRY_ID ($TIPO)"
