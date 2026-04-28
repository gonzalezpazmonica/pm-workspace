#!/usr/bin/env bash
# reconciliation-status.sh — SPEC-SE-035 Slice 1+3: tenant reconciliation CLI.
#
# Renders the green/amber/red reconciliation status for a tenant across all
# active dimensions registered in `reconciliation_dimensions`. Calls the
# `tenant_reconciliation_status(tenant, dimension)` SQL primitive defined in
# templates/reconciliation.sql for each active dimension and assembles a
# single colored table.
#
# Defines tier alarm: --fail-on red|amber returns non-zero exit when any row
# is at the requested tier. Useful for CI gates (e.g. red bloquea release).
#
# Requires:
#   - SAVIA_ENTERPRISE_DSN     Postgres DSN
#   - psql command available
#   - delta-tier.sh sibling for color rendering
#
# Usage:
#   reconciliation-status.sh --tenant <uuid>
#   reconciliation-status.sh --tenant <uuid> --json
#   reconciliation-status.sh --tenant <uuid> --fail-on red
#   reconciliation-status.sh --tenant <uuid> --dimension budget
#
# Exit codes:
#   0  ok (or no rows match alarm)
#   2  usage / args invalid
#   3  SAVIA_ENTERPRISE_DSN missing
#   4  psql missing
#   5  query failed
#   7  alarm triggered (--fail-on tier matched ≥1 row)
#
# Reference: SPEC-SE-035 (docs/propuestas/savia-enterprise/SPEC-SE-035-reconciliation-delta-engine.md)
# Pattern source: dreamxist/balance supabase/migrations/00009_reconciliation.sql (MIT, clean-room)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TENANT=""
DIMENSION=""
FAIL_ON=""
JSON_OUT=0

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant)    TENANT="$2"; shift 2 ;;
    --dimension) DIMENSION="$2"; shift 2 ;;
    --fail-on)   FAIL_ON="$2"; shift 2 ;;
    --json)      JSON_OUT=1; shift ;;
    -h|--help)   usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

# ── Pre-flight ───────────────────────────────────────────────────────────────

if [[ -z "$TENANT" ]]; then
  echo "ERROR: --tenant <uuid> required" >&2
  exit 2
fi

if ! [[ "$TENANT" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
  echo "ERROR: --tenant must be a UUID" >&2
  exit 2
fi

case "$FAIL_ON" in
  ""|"green"|"amber"|"red") ;;
  *) echo "ERROR: --fail-on must be one of green|amber|red (got: $FAIL_ON)" >&2; exit 2 ;;
esac

if [[ -z "${SAVIA_ENTERPRISE_DSN:-}" ]]; then
  echo "ERROR: SAVIA_ENTERPRISE_DSN env not set." >&2
  exit 3
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql not found." >&2
  exit 4
fi

# ── Build query ──────────────────────────────────────────────────────────────

TENANT_ESC="${TENANT//\'/\'\'}"

if [[ -n "$DIMENSION" ]]; then
  DIM_ESC="${DIMENSION//\'/\'\'}"
  DIM_FILTER="AND d.dimension = '$DIM_ESC'"
else
  DIM_FILTER=""
fi

# Iterate every active dimension and call the SQL primitive
SQL=$(cat <<SQL
WITH dims AS (
  SELECT dimension FROM reconciliation_dimensions d
   WHERE active = true $DIM_FILTER
)
SELECT
  d.dimension,
  (tenant_reconciliation_status('$TENANT_ESC'::uuid, d.dimension))->>'declared' AS declared,
  (tenant_reconciliation_status('$TENANT_ESC'::uuid, d.dimension))->>'computed' AS computed,
  (tenant_reconciliation_status('$TENANT_ESC'::uuid, d.dimension))->>'delta'    AS delta,
  (tenant_reconciliation_status('$TENANT_ESC'::uuid, d.dimension))->>'tier'     AS tier
FROM dims d
ORDER BY 5 DESC, 1
SQL
)

# ── Render ───────────────────────────────────────────────────────────────────

if [[ "$JSON_OUT" -eq 1 ]]; then
  JSON_SQL="SELECT jsonb_agg(jsonb_build_object(
              'tenant_id','$TENANT_ESC',
              'dimension', d.dimension,
              'status', tenant_reconciliation_status('$TENANT_ESC'::uuid, d.dimension)
            ))
            FROM reconciliation_dimensions d
            WHERE active = true $DIM_FILTER"
  out=$(psql "$SAVIA_ENTERPRISE_DSN" -At -c "$JSON_SQL" 2>&1) || {
    echo "ERROR: query failed: $out" >&2
    exit 5
  }
  printf '%s\n' "$out"
else
  rows=$(psql "$SAVIA_ENTERPRISE_DSN" -At -F '|' -c "$SQL" 2>&1) || {
    echo "ERROR: query failed: $rows" >&2
    exit 5
  }

  printf '%-30s %-15s %-15s %-15s %-8s\n' "DIMENSION" "DECLARED" "COMPUTED" "DELTA" "TIER"
  printf '%-30s %-15s %-15s %-15s %-8s\n' "---------" "--------" "--------" "-----" "----"
  while IFS='|' read -r dim declared computed delta tier; do
    [[ -z "$dim" ]] && continue
    case "$tier" in
      green) symbol=$'\033[32m●\033[0m green' ;;
      amber) symbol=$'\033[33m●\033[0m amber' ;;
      red)   symbol=$'\033[31m●\033[0m red  ' ;;
      *)     symbol="? $tier" ;;
    esac
    printf '%-30s %-15s %-15s %-15s %s\n' "$dim" "$declared" "$computed" "$delta" "$symbol"
  done <<< "$rows"
fi

# ── Alarm enforcement (--fail-on) ───────────────────────────────────────────

if [[ -n "$FAIL_ON" ]]; then
  ALARM_SQL="SELECT count(*) FROM reconciliation_dimensions d
             WHERE active = true $DIM_FILTER
               AND (tenant_reconciliation_status('$TENANT_ESC'::uuid, d.dimension))->>'tier' = '$FAIL_ON'"
  count=$(psql "$SAVIA_ENTERPRISE_DSN" -At -c "$ALARM_SQL" 2>&1) || {
    echo "ERROR: alarm query failed: $count" >&2
    exit 5
  }
  if [[ "$count" -gt 0 ]]; then
    echo "ALARM: $count dimension(s) at tier '$FAIL_ON'" >&2
    exit 7
  fi
fi
