#!/usr/bin/env bash
# learning-federate.sh — SCL-002: consume lecciones aprendidas de la cúpula
# SaviaLearning como propuestas INFERRED locales.
#
# La cúpula es cross-instancia: cualquier savia puede leer las lecciones que
# otros persistieron. Este script importa una lección de la cúpula como
# propuesta local (INFERRED, shadow — sin efecto) para que esta instancia la
# evalúe y, si procede, la active con aprobación humana. NUNCA auto-activa.
#
# Usage:
#   learning-federate.sh --from-vault <path> [--output-dir <dir>] [--list]
#   learning-federate.sh --list          # lista lecciones disponibles en la cúpula
#
# Exit codes: 0 ok, 2 usage, 3 vault missing
#
# Ref: docs/specs/SCL-002-cupula-aprendizaje.spec.md
# PURE_BASH — sin bindings de frontend.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VAULT="${SCL_VAULT_DIR:-$ROOT/vaults/SaviaLearning}"
OUTPUT_DIR="${SCL_PROPOSALS_DIR:-$ROOT/docs/learning-proposals}"
LIST_ONLY=false
IMPORT_ID=""

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
    -h|--help) usage ;;
    *) shift ;;
  esac
done

[[ -d "$VAULT" ]] || { echo "ERROR: vault not found: $VAULT" >&2; exit 3; }
LEARN_DIR="$VAULT/learning"
[[ -d "$LEARN_DIR" ]] || { echo "ERROR: no learning dir in vault: $LEARN_DIR" >&2; exit 3; }

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
