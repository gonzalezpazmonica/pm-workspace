#!/usr/bin/env bash
# learning-federate.sh — SCL-002/007: consume y comparte lecciones aprendidas
# de la cúpula SaviaLearning.
#
# - Import (SCL-002): trae una lección de la cúpula como propuesta local
#   INFERRED (shadow, sin efecto), pendiente de human_authored. NUNCA auto-activa.
# - Share (SCL-007): envía una lección a un dome remoto vía A2A (/share) —
#   federación cross-instancia real entre servidores SaviaVaults.
#
# Usage:
#   learning-federate.sh --list                       # lista lecciones locales
#   learning-federate.sh --import <id> [--output-dir] # importa como INFERRED
#   learning-federate.sh --share <id> --to <url> [--token]  # push a dome remoto
#   learning-federate.sh --search-remote --url <url> --query <q>  # busca en remoto
#
# Exit codes: 0 ok, 1 ya existe, 2 usage, 3 no encontrado/fail
#
# Ref: docs/specs/SCL-002-cupula-aprendizaje.spec.md,
#      docs/specs/SCL-007-federacion-crossdome.spec.md
# PURE_BASH — sin bindings de frontend.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VAULT="${SCL_VAULT_DIR:-$ROOT/vaults/SaviaLearning}"
OUTPUT_DIR="${SCL_PROPOSALS_DIR:-$ROOT/docs/learning-proposals}"
LIST_ONLY=false
IMPORT_ID=""
SHARE_ID=""
REMOTE_URL=""
REMOTE_TOKEN=""
SEARCH_REMOTE=false
REMOTE_QUERY=""

usage() {
  sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-vault) VAULT="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --list) LIST_ONLY=true; shift ;;
    --import) IMPORT_ID="$2"; shift 2 ;;
    --share) SHARE_ID="$2"; shift 2 ;;
    --to) REMOTE_URL="$2"; shift 2 ;;
    --token) REMOTE_TOKEN="$2"; shift 2 ;;
    --search-remote) SEARCH_REMOTE=true; shift ;;
    --url) REMOTE_URL="$2"; shift 2 ;;
    --query) REMOTE_QUERY="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) shift ;;
  esac
done

# ── Modo search-remote (SCL-007): busca en un dome remoto via /search ──
if $SEARCH_REMOTE; then
  [[ -z "$REMOTE_URL" || -z "$REMOTE_QUERY" ]] && { echo "ERROR: --url y --query requeridos con --search-remote" >&2; exit 2; }
  AUTH=(); [[ -n "$REMOTE_TOKEN" ]] && AUTH=(-H "Authorization: Bearer $REMOTE_TOKEN")
  RESP=$(curl -s --max-time 8 "${AUTH[@]}" "$REMOTE_URL/search?q=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$REMOTE_QUERY")&maxResults=5" 2>/dev/null) || true
  if [[ -z "$RESP" ]]; then echo "ERROR: no response de $REMOTE_URL" >&2; exit 3; fi
  echo "=== Lecciones del dome remoto: $REMOTE_URL ==="
  echo "$RESP" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    for r in d.get('results',[]):
        if 'learning/' in r.get('path',''):
            print(f\"- {r['path']} (score {r.get('score',0):.2f})\")
except Exception as e:
    print('ERROR parsing:', e)" 2>&1
  exit 0
fi

[[ -d "$VAULT" ]] || { echo "ERROR: vault not found: $VAULT" >&2; exit 3; }
LEARN_DIR="$VAULT/learning"
[[ -d "$LEARN_DIR" ]] || { echo "ERROR: no learning dir in vault: $LEARN_DIR" >&2; exit 3; }

# ── Modo share (SCL-007): envía una lección a un dome remoto via /share ──
if [[ -n "$SHARE_ID" ]]; then
  [[ -z "$REMOTE_URL" ]] && { echo "ERROR: --to <url> requerido con --share" >&2; exit 2; }
  SRC="$LEARN_DIR/${SHARE_ID}.md"
  [[ -f "$SRC" ]] || { echo "ERROR: lesson not found: $SHARE_ID" >&2; exit 3; }
  CONTENT=$(cat "$SRC")
  PAYLOAD=$(python3 -c "import json,sys;print(json.dumps({'path':'learning/$SHARE_ID.md','content':sys.argv[1]}))" "$CONTENT")
  AUTH=(); [[ -n "$REMOTE_TOKEN" ]] && AUTH=(-H "Authorization: Bearer $REMOTE_TOKEN")
  RESP=$(curl -s --max-time 8 -X POST "${AUTH[@]}" -H 'Content-Type: application/json' \
    -d "$PAYLOAD" "$REMOTE_URL/share" 2>/dev/null) || true
  if echo "$RESP" | grep -q '"path"'; then
    echo "SHARED: learning/${SHARE_ID}.md → $REMOTE_URL"
    echo "source_dome: SaviaLearning"
    exit 0
  fi
  echo "ERROR: share fallo — respuesta: ${RESP:-sin respuesta}" >&2
  exit 3
fi

if $LIST_ONLY; then
  echo "=== Lecciones aprendidas disponibles en la cúpula ==="
  for f in "$LEARN_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    id=$(grep -m1 '^  id: ' "$f" | sed 's/^  id: //')
    life=$(grep -m1 '^  lifecycle: ' "$f" | sed 's/^  lifecycle: //')
    prov=$(grep -m1 '^  provenance: ' "$f" | sed 's/^  provenance: //')
    target=$(grep -m1 '^  target: ' "$f" | sed 's/^  target: //')
    echo "- ${id} [${life}/${prov}] target=${target}"
  done
  exit 0
fi

# ── Import a specific lesson as local INFERRED proposal ──
if [[ -z "$IMPORT_ID" ]]; then
  echo "ERROR: --import <id> required (use --list para ver ids)" >&2
  exit 2
fi
SRC="$LEARN_DIR/${IMPORT_ID}.md"
[[ -f "$SRC" ]] || { echo "ERROR: lesson not found: $IMPORT_ID" >&2; exit 3; }

# Extraer campos de la nota de cúpula
ORIGIN=$(grep -m1 '^  origin: ' "$SRC" | sed 's/^  origin: //')
TRIGGER=$(grep -m1 '^  trigger: ' "$SRC" | sed 's/^  trigger: //')
TARGET=$(grep -m1 '^  target: ' "$SRC" | sed 's/^  target: //')
EHASH=$(grep -m1 '^  evidence_hash: ' "$SRC" | sed 's/^  evidence_hash: //')
DIAG=$(sed -n '/^## Diagnóstico/,/^## Cambio propuesto/p' "$SRC" | grep -v '^##' | grep -v '^$' | head -2 | tr '\n' ' ' | sed 's/  */ /g')
CHANGE=$(sed -n '/^## Cambio propuesto/,/^## Origen/p' "$SRC" | grep -v '^##' | grep -v '^$' | head -2 | tr '\n' ' ' | sed 's/  */ /g')
FED_ORIGIN="[federada de la cúpula] $ORIGIN"

mkdir -p "$OUTPUT_DIR"
LOCAL_FILE="$OUTPUT_DIR/${IMPORT_ID}.md"

# No duplicar si ya importada
if [[ -f "$LOCAL_FILE" ]]; then
  echo "ALREADY: $IMPORT_ID ya importada localmente"
  exit 1
fi

CREATED_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$LOCAL_FILE" <<EOF
---
id: $IMPORT_ID
type: learning_proposal
provenance: INFERRED
lifecycle: proposed
origin: $FED_ORIGIN
trigger: $TRIGGER
target: $TARGET
evidence_hash: $EHASH
created_utc: $CREATED_UTC
federated: true
source_dome: SaviaLearning
---

# Learning Proposal $IMPORT_ID (federada)

## Origen

$FED_ORIGIN

## Evidencia

$EHASH (hash de la cúpula)

## Diagnóstico

$DIAG

## Cambio propuesto

$CHANGE

## Destino

$TARGET
EOF

echo "IMPORTED: $LOCAL_FILE"
echo "id: $IMPORT_ID"
echo "source_dome: SaviaLearning"
exit 0
