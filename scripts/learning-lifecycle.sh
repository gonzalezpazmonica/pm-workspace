#!/usr/bin/env bash
# learning-lifecycle.sh — SCL-001 S2: sustrato como artefacto de despliegue
#
# State machine for learning proposals / sustrado entries:
#   proposed(shadow) → canary → active → superseded
#
# - shadow: no effect on gates or behaviour (equivale a INFERRED).
# - canary: active on a declared subset, with before/after measurement.
# - active: human_authored, global effect.
# - superseded: tombstone + quarantine window (CRIT-024), never deleted.
#
# Gate anti-auto-activación (CRIT-031 / ART-11): proposed→active and
# canary→active REQUIRE provenance:human_authored with a human trailer.
# No transition to active may originate from an agent. active→superseded and
# rollback ARE automatable (reversible, CRIT-022).
#
# Usage:
#   learning-lifecycle.sh --file <artifact.md> --to <state> \
#     [--actor <who>] [--reason <why>] [--human-trailer <sig>] \
#     [--subset <domain>] [--metric-before <L>] [--metric-after <L>] \
#     [--ledger <path>] [--strict]
#
# Exit codes: 0 ok, 1 invalid transition, 2 usage, 3 missing file,
#             4 human_authored required, 5 canary metric regression
#
# Ref: docs/specs/SCL-001-aprendizaje-continuo.spec.md (S2, AC-2.1..2.6)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FILE=""
TO=""
ACTOR="agent"
REASON=""
HUMAN_TRAILER=""
SUBSET=""
METRIC_BEFORE=""
METRIC_AFTER=""
LEDGER="${SCL_LEDGER:-$ROOT/output/learning-loop/lifecycle.jsonl}"
STRICT=false

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE="$2"; shift 2 ;;
    --to) TO="$2"; shift 2 ;;
    --actor) ACTOR="$2"; shift 2 ;;
    --reason) REASON="$2"; shift 2 ;;
    --human-trailer) HUMAN_TRAILER="$2"; shift 2 ;;
    --subset) SUBSET="$2"; shift 2 ;;
    --metric-before) METRIC_BEFORE="$2"; shift 2 ;;
    --metric-after) METRIC_AFTER="$2"; shift 2 ;;
    --ledger) LEDGER="$2"; shift 2 ;;
    --strict) STRICT=true; shift ;;
    -h|--help) usage ;;
    *) shift ;;
  esac
done

[[ -z "$FILE" || -z "$TO" ]] && usage
[[ -f "$FILE" ]] || { echo "ERROR: file not found: $FILE" >&2; exit 3; }

case "$TO" in
  proposed|canary|active|superseded) ;;
  *) echo "ERROR: --to debe ser proposed|canary|active|superseded" >&2; exit 2 ;;
esac

CURRENT=$(grep -m1 '^lifecycle: ' "$FILE" | sed 's/^lifecycle: //' || echo "proposed")
PROV=$(grep -m1 '^provenance: ' "$FILE" | sed 's/^provenance: //' || echo "INFERRED")
ID=$(grep -m1 '^id: ' "$FILE" | sed 's/^id: //' || basename "$FILE" .md)

# ── Valid transitions ──
valid=false
case "$CURRENT" in
  proposed)
    case "$TO" in proposed|canary) valid=true ;; esac ;;
  canary)
    case "$TO" in canary|active|proposed|superseded) valid=true ;; esac ;;
  active)
    case "$TO" in active|superseded) valid=true ;; esac ;;
  superseded)
    case "$TO" in superseded) valid=true ;; esac ;;
esac

# proposed→active / canary→active require human_authored (CRIT-031, AC-2.4)
if [[ "$TO" == "active" ]]; then
  if [[ -z "$HUMAN_TRAILER" ]]; then
    if $STRICT; then
      echo "BLOCKED [learning-lifecycle]: transition to active requires --human-trailer (CRIT-031/ART-11)" >&2
      exit 4
    fi
    # non-strict: record the violation attempt but refuse the transition
    echo "REFUSED: active requires human_authored trailer" >&2
    mkdir -p "$(dirname "$LEDGER")"
    {
      printf '%s' '{"id":"'"$ID"'","from":"'"$CURRENT"'","to":"active","actor":"'"$ACTOR"'",'
      printf '%s' '"status":"refused-no-human","reason":"'"$REASON"'","ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}'
      echo ""
    } >> "$LEDGER"
    exit 4
  fi
fi

# canary→active promotion conditioned on metric (AC-2.5): metric_after must be >= metric_before
if [[ "$CURRENT" == "canary" && "$TO" == "active" ]] && [[ -n "$METRIC_BEFORE" && -n "$METRIC_AFTER" ]]; then
  if awk -v b="$METRIC_BEFORE" -v a="$METRIC_AFTER" 'BEGIN{exit (a < b)}'; then
    : # promotion allowed: after >= before
  else
    echo "BLOCKED [learning-lifecycle]: canary metric regression (before=$METRIC_BEFORE after=$METRIC_AFTER) — no ascends, reverting" >&2
    # revert to proposed (shadow) with cause registered
    TO="proposed"
    REASON="canary regression: before=$METRIC_BEFORE after=$METRIC_AFTER ($REASON)"
    RECORD_REVERT=true
  fi
fi

[[ "$valid" == "true" ]] || { echo "ERROR: invalid transition $CURRENT → $TO" >&2; exit 1; }

# ── Apply transition ──
sed -i "s/^lifecycle: .*/lifecycle: $TO/" "$FILE"
# active sets provenance human_authored; other states stay INFERRED
if [[ "$TO" == "active" ]]; then
  sed -i "s/^provenance: .*/provenance: human_authored/" "$FILE"
  sed -i "s/^human_trailer:.*/human_trailer: $HUMAN_TRAILER/" "$FILE" \
    || sed -i "/^created_utc:/a human_trailer: $HUMAN_TRAILER" "$FILE"
  sed -i "/^human_trailer:/d;/^created_utc:/a human_trailer: $HUMAN_TRAILER" "$FILE"
elif [[ "$TO" == "superseded" ]]; then
  # tombstone: keep the file readable, add tombstone marker (CRIT-024)
  sed -i "/^lifecycle:/a tombstone: superseded $(date -u +%Y-%m-%dT%H:%M:%SZ) — no borrado, cuarentena (CRIT-024)" "$FILE"
fi

# ── Record transition ──
mkdir -p "$(dirname "$LEDGER")"
{
  printf '%s' '{"id":"'"$ID"'","from":"'"$CURRENT"'","to":"'"$TO"'","actor":"'"$ACTOR"'",'
  printf '%s' '"reason":"'"$REASON"'","ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",'
  printf '%s' '"metric_before":"'"$METRIC_BEFORE"'","metric_after":"'"$METRIC_AFTER"'"'
  printf '%s' ',"revert":"'"${RECORD_REVERT:-false}"'"'
  echo "}"
} >> "$LEDGER"

echo "TRANSITION: $CURRENT → $TO (id=$ID actor=$ACTOR)"
exit 0
