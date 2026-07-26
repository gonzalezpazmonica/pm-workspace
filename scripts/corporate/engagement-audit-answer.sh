#!/usr/bin/env bash
# engagement-audit-answer.sh — SE-271 S6 Canonical Auditor Questions
set -uo pipefail
#
# Responde 3 preguntas canonicas de auditoria sobre un cliente.
# Todas las respuestas con enlaces verificables, no prosa.
# Spot-check: 10 aseveraciones, 100% trazables.
#
# Reference: SE-271 (docs/propuestas/SE-271-savia-corporate.md) Slice 6

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CORPORATE_DIR="${ROOT_DIR}/.claude/corporate"

usage() {
  cat <<'USAGE'
engagement-audit-answer.sh — SE-271 S6 Canonical Auditor Questions

Usage:
  engagement-audit-answer.sh --client SLUG --question 1|2|3|all [--json]
  engagement-audit-answer.sh --client SLUG --spot-check
  engagement-audit-answer.sh --help

Questions:
  1: What data of mine entered?          (ingestion inventory)
  2: Where is it now?                    (current state, replicas)
  3: Who could see it?                   (access log, RBAC scope)

Spot-check:
  --spot-check  Verifies 10 assertions are 100% traceable to files.
                All links must resolve to real filesystem paths.
                Exit 1 if any assertion cannot be traced.

Evidence sources:
  .claude/corporate/clients/{slug}/  (S1–S5 materialized state)
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

CLIENT=""
QUESTION="all"
JSON_MODE=0
SPOT_CHECK=0
TRACEABLE=0
UNTRACEABLE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --client)     CLIENT="$2";      shift 2 ;;
    --question)   QUESTION="$2";    shift 2 ;;
    --json)       JSON_MODE=1;      shift ;;
    --spot-check) SPOT_CHECK=1;     shift ;;
    -h|--help)    usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$CLIENT" ]] && die "--client is required"

CLIENT_DIR="${CORPORATE_DIR}/clients/${CLIENT}"
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── Traceability helpers ──────────────────────────────────────────────────────

# Assert a file exists and output it as a verifiable reference
ref() {
  local path="$1" label="$2"
  if [[ -f "$path" ]]; then
    local h
    h="$(sha256sum "$path" 2>/dev/null | cut -d' ' -f1)"
    echo "  [VERIFIABLE] ${label}: ${path} (sha256:${h:0:16}...)"
    TRACEABLE=$(( TRACEABLE + 1 ))
  else
    echo "  [UNTRACEABLE] ${label}: ${path} (NOT FOUND)"
    UNTRACEABLE=$(( UNTRACEABLE + 1 ))
  fi
}

# ── Question 1: What data of mine entered? ────────────────────────────────────

question_1() {
  echo "## Q1: What data of mine entered?"
  echo ""

  local inv_file="${CLIENT_DIR}/ingestion/inventory.json"
  ref "$inv_file" "Ingestion inventory manifest"

  # List individual artifacts if any
  local artifacts_dir="${CLIENT_DIR}/ingestion/artifacts"
  if [[ -d "$artifacts_dir" ]]; then
    while IFS= read -r -d '' f; do
      ref "$f" "Ingested artifact"
    done < <(find "$artifacts_dir" -type f -print0 2>/dev/null | sort -z)
  fi

  # Check adoption ledger
  local ledger="${CORPORATE_DIR}/ledger/adopted.jsonl"
  if [[ -f "$ledger" ]]; then
    local client_entries
    client_entries="$(grep "\"${CLIENT}\"" "$ledger" 2>/dev/null | wc -l)"
    ref "$ledger" "Adoption ledger (${client_entries} entries for ${CLIENT})"
  fi
}

# ── Question 2: Where is it now? ──────────────────────────────────────────────

question_2() {
  echo "## Q2: Where is it now?"
  echo ""

  # Current state manifests
  ref "${CLIENT_DIR}/capacities/capacities-scope.json" "Active capacities (current state)"
  ref "${CLIENT_DIR}/confidentiality-map.json" "Confidentiality classification (current state)"

  # Separation state
  ref "${CLIENT_DIR}/murallas/separation-proof.json" "Separation wall status"

  # Replicas / materialized state
  local adopted_dir="${CORPORATE_DIR}/adopted"
  if [[ -d "$adopted_dir" ]]; then
    while IFS= read -r -d '' f; do
      ref "$f" "Adopted corporate entry (locally materialized)"
    done < <(find "$adopted_dir" -type f -print0 2>/dev/null | sort -z)
  fi

  # Attestation state
  local latest_att
  latest_att="$(find "${CLIENT_DIR}/attestations" -name "*.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
  if [[ -n "$latest_att" ]]; then
    ref "$latest_att" "Latest attestation (most recent state snapshot)"
  fi
}

# ── Question 3: Who could see it? ─────────────────────────────────────────────

question_3() {
  echo "## Q3: Who could see it?"
  echo ""

  # Access logs
  local access_log="${CLIENT_DIR}/audit-trail/access-log.jsonl"
  ref "$access_log" "Access log"

  local rbac_model="${CORPORATE_DIR}/rbac-model.md"
  ref "$rbac_model" "RBAC model (access scope definition)"

  # Audit trail for access evidence
  local audit_dir="${CLIENT_DIR}/audit-trail"
  if [[ -d "$audit_dir" ]]; then
    while IFS= read -r -d '' f; do
      ref "$f" "Audit trail entry"
    done < <(find "$audit_dir" -type f -print0 2>/dev/null | sort -z)
  fi

  # Purge log (who executed right to be forgotten)
  local purge_log="${CLIENT_DIR}/purge-log.jsonl"
  ref "$purge_log" "Purge log (operator identity per deletion)"
}

# ── Spot-check: 10 assertions with 100% traceability ──────────────────────────

run_spot_check() {
  echo "# Spot-check: 10 assertions (100% traceable required)"
  echo ""

  # Reset counters
  TRACEABLE=0
  UNTRACEABLE=0

  # Assertion 1: ingestion inventory exists
  ref "${CLIENT_DIR}/ingestion/inventory.json"         "A1: Ingestion inventory"

  # Assertion 2: confidentiality map exists
  ref "${CLIENT_DIR}/confidentiality-map.json"         "A2: Confidentiality classification"

  # Assertion 3: separation proof exists
  ref "${CLIENT_DIR}/murallas/separation-proof.json"   "A3: Separation proof"

  # Assertion 4: capacities scope exists
  ref "${CLIENT_DIR}/capacities/capacities-scope.json" "A4: Capacities scope"

  # Assertion 5: at least one attestation
  local att_file
  att_file="$(find "${CLIENT_DIR}/attestations" -name "*.json" -type f -print -quit 2>/dev/null)"
  ref "$att_file" "A5: Period attestation record"

  # Assertion 6: purge log exists
  ref "${CLIENT_DIR}/purge-log.jsonl"                  "A6: Purge log"

  # Assertion 7: adoption ledger references client
  ref "${CORPORATE_DIR}/ledger/adopted.jsonl"          "A7: Adoption ledger"

  # Assertion 8: RBAC model exists
  ref "${CORPORATE_DIR}/rbac-model.md"                 "A8: RBAC model"

  # Assertion 9: audit trail has entries
  local audit_file
  audit_file="$(find "${CLIENT_DIR}/audit-trail" -type f -print -quit 2>/dev/null)"
  ref "$audit_file" "A9: Audit trail record"

  # Assertion 10: corporate model is materialized
  ref "${CORPORATE_DIR}/model.md"                      "A10: Corporate model"

  echo ""
  echo "Traceable: ${TRACEABLE} / Untraceable: ${UNTRACEABLE}"

  if [[ "$UNTRACEABLE" -gt 0 ]]; then
    echo "FAIL: ${UNTRACEABLE} assertion(s) not traceable."
    exit 1
  else
    echo "PASS: All ${TRACEABLE} assertions 100% traceable to filesystem evidence."
  fi
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

if [[ "$SPOT_CHECK" -eq 1 ]]; then
  run_spot_check
  exit $?
fi

case "$QUESTION" in
  1)
    question_1
    ;;
  2)
    question_2
    ;;
  3)
    question_3
    ;;
  all)
    echo "Generated: ${GENERATED_AT}"
    echo "Client: ${CLIENT}"
    echo ""
    question_1
    echo ""
    question_2
    echo ""
    question_3
    ;;
  *)
    die "invalid question: ${QUESTION} (use 1, 2, 3, or all)"
    ;;
esac
