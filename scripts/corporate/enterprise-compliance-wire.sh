#!/usr/bin/env bash
# enterprise-compliance-wire.sh — SE-271 S6 Wire Existing Enterprise Compliance Scripts
set -uo pipefail
#
# Clasifica los scripts enterprise existentes como wired | archived.
# Mismos criterios que S4 enterprise reconcile. Cero en limbo.
#
# Scripts evaluados:
#   - compliance-evidence-collector.sh (SPEC-SE-026)
#   - governance-audit-trail.sh      (SPEC-SE-006)
#   - audit-search.sh                (SPEC-SE-037)
#   - audit-purge.sh                 (SPEC-SE-037)
#
# Criterios de clasificacion:
#   wired   → funcionalidad cubierta por nuevo modelo corporativo (SE-271),
#             el script sigue siendo relevante y utilizable
#   archived → funcionalidad superada por SE-271 (nuevas estructuras
#              .claude/corporate/ reemplazan su proposito)
#
# Reference: SE-271 (docs/propuestas/SE-271-savia-corporate.md) Slice 6

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENTERPRISE_DIR="${ROOT_DIR}/scripts/enterprise"

usage() {
  cat <<'USAGE'
enterprise-compliance-wire.sh — SE-271 S6 Wire Enterprise Compliance Scripts

Usage:
  enterprise-compliance-wire.sh [--json]
  enterprise-compliance-wire.sh --help

Classifies existing compliance scripts:
  wired   → retained, still serves purpose in corporate model
  archived → superseded by SE-271 corporate structures

Zero scripts in limbo — every script has a disposition.
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

JSON_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_MODE=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── Wire classification ──────────────────────────────────────────────────────

# Each entry: script name → {status, rationale}
# status: wired | archived
# rationale: why this classification

declare -A STATUS=()
declare -A RATIONALE=()

classify() {
  local script="$1" status="$2" rationale="$3"
  STATUS["$script"]="$status"
  RATIONALE["$script"]="$rationale"
}

# ── compliance-evidence-collector.sh ──────────────────────────────────────────
#
# SPEC-SE-026. Collects compliance evidence (model cards, audit trail, policies)
# into output/compliance-evidence/. This is a generic collect-and-bundle tool
# that operates on workspace-level artifacts, not client-specific.
#
# Verdict: WIRED — remains useful as a generic workspace-level evidence
# collector. SE-271's engagement-evidence-package.sh complements it by
# generating per-client evidence. They serve different scopes (workspace vs
# client) so the collector is not superseded.

classify "compliance-evidence-collector.sh" "wired" \
  "Workspace-level evidence collector (SE-026). Complements SE-271 client-scoped packages. Non-overlapping scope."

# ── governance-audit-trail.sh ─────────────────────────────────────────────────
#
# SPEC-SE-006. Manages append/verify/export/chain-status on audit trails
# stored in .claude/enterprise/audit/{tenant}/audit-trail.jsonl. The
# mechanisms (sha256 chain hashing, JSONL storage) are sound and the
# corporate model (SE-271) does not change how audit entries are
# cryptographically chained. Client-specific audits (SE-271 S6) build on
# the same chain-of-custody concept.
#
# Verdict: WIRED — the chain-of-custody mechanism is foundational.
# SE-271 clients use the same hash-chain model for their audit trails.

classify "governance-audit-trail.sh" "wired" \
  "Cryptographic audit trail with sha256 chain (SE-006). Foundational mechanism adopted by SE-271 per-client audit."

# ── audit-search.sh ───────────────────────────────────────────────────────────
#
# SPEC-SE-037. Searches Postgres audit_log table. Requires SAVIA_ENTERPRISE_DSN.
# This is a DSN-dependent infrastructure tool, not a corporate concept tool.
# SE-271 corporate model is DSN-independent (local text materialization).
# However, anyone who has a DSN still needs to query audit_log.
#
# Verdict: WIRED — operates at infrastructure level (Postgres), not at
# corporate model level. Non-overlapping scopes.

classify "audit-search.sh" "wired" \
  "Postgres audit_log query tool (SE-037). Infrastructure-level, DSN-dependent. Non-overlapping with SE-271 text-based model."

# ── audit-purge.sh ────────────────────────────────────────────────────────────
#
# SPEC-SE-037. Selective DELETE on audit_log with retention policy gate.
# Requires PGDATABASE. Same infra-level scope as audit-search.
#
# Verdict: WIRED — infrastructure-level. SE-271 adds per-client purge
# records (purge-log.jsonl) as evidence, but the actual Postgres-level
# purge is a separate concern.

classify "audit-purge.sh" "wired" \
  "Postgres audit_log selective DELETE (SE-037). Infrastructure-level. SE-271 complements with per-client purge records."

# ── Classification results ────────────────────────────────────────────────────

RESULTS=""
LIMBO_COUNT=0
WIRED_COUNT=0
ARCHIVED_COUNT=0

for script in compliance-evidence-collector.sh governance-audit-trail.sh audit-search.sh audit-purge.sh; do
  script_status="${STATUS[$script]}"
  script_rationale="${RATIONALE[$script]}"

  case "$script_status" in
    wired)   WIRED_COUNT=$(( WIRED_COUNT + 1 )) ;;
    archived) ARCHIVED_COUNT=$(( ARCHIVED_COUNT + 1 )) ;;
    *) LIMBO_COUNT=$(( LIMBO_COUNT + 1 )) ;;
  esac

  sep=""
  [[ -n "$RESULTS" ]] && sep=","
  RESULTS+="${sep}{\"script\":\"${script}\",\"status\":\"${script_status}\",\"rationale\":\"${script_rationale}\"}"
done

# ── Zero-in-limbo verification ────────────────────────────────────────────────

if [[ "$LIMBO_COUNT" -gt 0 ]]; then
  echo "ERROR: ${LIMBO_COUNT} scripts in LIMBO — every script must be wired or archived." >&2
  exit 1
fi

# ── Output ────────────────────────────────────────────────────────────────────

if [[ "$JSON_MODE" -eq 1 ]]; then
  cat <<JSON
{
  "_spec": "SE-271 S6",
  "_generated_at": "${GENERATED_AT}",
  "_principle": "Zero scripts in limbo. All classified: wired | archived.",
  "total": $(( WIRED_COUNT + ARCHIVED_COUNT )),
  "wired": ${WIRED_COUNT},
  "archived": ${ARCHIVED_COUNT},
  "limbo": 0,
  "scripts": [${RESULTS}]
}
JSON
else
  echo "Wire classification — ${GENERATED_AT}"
  echo ""
  echo "Total: $(( WIRED_COUNT + ARCHIVED_COUNT ))  |  wired: ${WIRED_COUNT}  |  archived: ${ARCHIVED_COUNT}  |  limbo: 0"
  echo ""
  for script in compliance-evidence-collector.sh governance-audit-trail.sh audit-search.sh audit-purge.sh; do
    disp_marker=""
    [[ "${STATUS[$script]}" == "wired" ]] && disp_marker="[WIRED]  "
    [[ "${STATUS[$script]}" == "archived" ]] && disp_marker="[ARCHIVED]"
    echo "${disp_marker} ${script}"
    echo "         ${RATIONALE[$script]}"
    echo ""
  done
  echo "Limbo: 0 — all scripts classified."
fi
