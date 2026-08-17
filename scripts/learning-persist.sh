#!/usr/bin/env bash
# learning-persist.sh — SCL-002: persiste una learning proposal en la cúpula
# SaviaLearning de SaviaVaults como nota con entidad tipada + relaciones + wikilinks.
#
# La cúpula es git-backed: escribir el markdown en vaults/SaviaLearning/learning/
# registra la nota (storage) y el frontmatter entity/relations la indexa en el
# grafo consultable (graph/query). El fichero en docs/learning-proposals/
# sigue siendo la fuente local; la cúpula es la persistencia cross-instancia.
#
# Usage:
#   learning-persist.sh --file <proposal.md> [--vault <path>] [--commit] [--dry-run]
#
# Exit codes: 0 ok, 1 ya persistida, 2 usage, 3 file/params invalidos
#
# Ref: docs/specs/SCL-002-cupula-aprendizaje.spec.md
# PURE_BASH — sin bindings de frontend.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FILE=""
VAULT="${SCL_VAULT_DIR:-$ROOT/vaults/SaviaLearning}"
DO_COMMIT=false
DRY_RUN=false

usage() {
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE="$2"; shift 2 ;;
    --vault) VAULT="$2"; shift 2 ;;
    --commit) DO_COMMIT=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage ;;
    *) shift ;;
  esac
done

[[ -z "$FILE" ]] && usage
[[ -f "$FILE" ]] || { echo "ERROR: proposal not found: $FILE" >&2; exit 3; }
[[ -d "$VAULT" ]] || { echo "ERROR: vault dir not found: $VAULT" >&2; exit 3; }

# ── Extract fields from the proposal frontmatter ──
ID=$(grep -m1 '^id: ' "$FILE" | sed 's/^id: //')
PROV=$(grep -m1 '^provenance: ' "$FILE" | sed 's/^provenance: //')
LIFE=$(grep -m1 '^lifecycle: ' "$FILE" | sed 's/^lifecycle: //')
ORIGIN=$(grep -m1 '^origin: ' "$FILE" | sed 's/^origin: //')
TRIGGER=$(grep -m1 '^trigger: ' "$FILE" | sed 's/^trigger: //')
TARGET=$(grep -m1 '^target: ' "$FILE" | sed 's/^target: //')
EHASH=$(grep -m1 '^evidence_hash: ' "$FILE" | sed 's/^evidence_hash: //')
CREATED=$(grep -m1 '^created_utc: ' "$FILE" | sed 's/^created_utc: //')
EXPECTED=$(grep -m1 '^expected_p_consistent: ' "$FILE" | sed 's/^expected_p_consistent: //')

[[ -z "$ID" ]] && { echo "ERROR: proposal missing id" >&2; exit 3; }

# ── Target path in the vault ──
VAULT_REL="learning/${ID}.md"
VAULT_FILE="$VAULT/$VAULT_REL"

# ── Skip if already persisted (idempotencia cross-instancia) ──
if [[ -f "$VAULT_FILE" ]]; then
  # evidence_hash aparece indentado bajo entity: (  evidence_hash: ...)
  if grep -qE "^[[:space:]]*evidence_hash: $EHASH" "$VAULT_FILE" 2>/dev/null; then
    echo "ALREADY: $ID persists in vault ($VAULT_REL)"
    exit 1
  fi
fi

# ── Build the vault note (markdown = truth, frontmatter = graph index) ──
# entity.type/id + relations + wikilinks → KnowledgeGraph.build()
mkdir -p "$VAULT/learning"

# Extraer cuerpo (diagnóstico + cambio) del proposal markdown
DIAG=$(sed -n '/^## Diagnóstico/,/^## Cambio propuesto/p' "$FILE" | grep -v '^##' | grep -v '^$' | head -3 | tr '\n' ' ' | sed 's/  */ /g')
CHANGE=$(sed -n '/^## Cambio propuesto/,/^## Destino/p' "$FILE" | grep -v '^##' | grep -v '^$' | head -3 | tr '\n' ' ' | sed 's/  */ /g')

REL_TARGET=""
case "$TARGET" in
  criterio) REL_TARGET="criterio" ;;
  memoria)  REL_TARGET="memoria" ;;
  skill)    REL_TARGET="skills" ;;
  spec)     REL_TARGET="specs" ;;
esac

NOTE="---
entity:
  type: learning_proposal
  id: $ID
  provenance: $PROV
  lifecycle: $LIFE
  origin: $ORIGIN
  trigger: $TRIGGER
  target: $TARGET
  evidence_hash: $EHASH
  created_utc: $CREATED
  expected_p_consistent: ${EXPECTED:-}
relations:
  - type: PROPOSES_CHANGE
    target: $TARGET
  - type: EVIDENCE_FROM
    target: $EHASH
  - type: MEASURED_BY
    target: metric-L
confidentiality: N2
tags: [scl, learning, $TARGET, $TRIGGER]
---

# $ID — Propuesta de Aprendizaje

## Diagnóstico

$DIAG

## Cambio propuesto

$CHANGE

## Origen

$ORIGIN

## Destino

$TARGET

## Ver también

- [[learning/$ID]] — esta nota
- [[decision]] — decisiones relacionadas
- [[metric-L]] — métrica del bucle
"

if $DRY_RUN; then
  echo "DRY-RUN: persistiria en $VAULT_REL"
  exit 0
fi

printf '%s\n' "$NOTE" > "$VAULT_FILE"

if $DO_COMMIT; then
  git -C "$VAULT" add "$VAULT_REL" 2>/dev/null && git -C "$VAULT" commit -qm "learning(SCL-002): persist $ID in SaviaLearning" 2>/dev/null \
    || echo "WARN: vault git commit fallo (cúpula no es repo git o sin cambios)"
fi

echo "PERSISTED: $VAULT_REL"
echo "id: $ID"
echo "vault: $VAULT"
exit 0
