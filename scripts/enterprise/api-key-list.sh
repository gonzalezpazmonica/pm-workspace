#!/usr/bin/env bash
# api-key-list.sh — SPEC-SE-036 Slice 2: API key inventory CLI.
#
# Lists API keys with prefix, scope, last_used_at, and revoked status. The
# plaintext is NEVER displayed (it is not stored). Filters: --tenant, --active,
# --revoked. Default: all keys for the connected DSN, sorted by last_used DESC.
#
# Requires:
#   - SAVIA_ENTERPRISE_DSN     Postgres DSN
#   - psql
#
# Usage:
#   api-key-list.sh                          # all keys, both active and revoked
#   api-key-list.sh --tenant <uuid>          # filter by tenant
#   api-key-list.sh --active                 # only active (revoked_at IS NULL)
#   api-key-list.sh --revoked                # only revoked
#   api-key-list.sh --json                   # JSON output for tooling
#
# Exit codes:
#   0  ok
#   2  usage / args invalid
#   3  SAVIA_ENTERPRISE_DSN missing
#   4  psql missing
#   5  query failed
#
# Reference: SPEC-SE-036 (`docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md`)
# Pattern source: `dreamxist/balance` (MIT, clean-room)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TENANT=""
ACTIVE_ONLY=0
REVOKED_ONLY=0
JSON_OUT=0

usage() {
  sed -n '2,23p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant)  TENANT="$2"; shift 2 ;;
    --active)  ACTIVE_ONLY=1; shift ;;
    --revoked) REVOKED_ONLY=1; shift ;;
    --json)    JSON_OUT=1; shift ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

if [[ "$ACTIVE_ONLY" -eq 1 && "$REVOKED_ONLY" -eq 1 ]]; then
  echo "ERROR: --active and --revoked are mutually exclusive" >&2
  exit 2
fi

# Validate UUID shape before any env/DSN/psql checks (cheap arg validation first)
if [[ -n "$TENANT" ]] && \
   ! [[ "$TENANT" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
  echo "ERROR: --tenant must be a UUID" >&2
  exit 2
fi

if [[ -z "${SAVIA_ENTERPRISE_DSN:-}" ]]; then
  echo "ERROR: SAVIA_ENTERPRISE_DSN env not set." >&2
  exit 3
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql not found." >&2
  exit 4
fi

# ── Build WHERE ──────────────────────────────────────────────────────────────

WHERE="WHERE 1=1"
[[ -n "$TENANT" ]] && WHERE="$WHERE AND tenant_id = '${TENANT//\'/\'\'}'::uuid"
[[ "$ACTIVE_ONLY"  -eq 1 ]] && WHERE="$WHERE AND revoked_at IS NULL"
[[ "$REVOKED_ONLY" -eq 1 ]] && WHERE="$WHERE AND revoked_at IS NOT NULL"

# ── Run query ────────────────────────────────────────────────────────────────

if [[ "$JSON_OUT" -eq 1 ]]; then
  SQL="SELECT to_jsonb(row_to_json(t)) FROM (
    SELECT key_prefix, tenant_id::text, scope, description,
           created_at, last_used_at, revoked_at, revoked_by
    FROM api_keys
    $WHERE
    ORDER BY last_used_at DESC NULLS LAST, created_at DESC
  ) t"
  out=$(psql "$SAVIA_ENTERPRISE_DSN" -At -c "$SQL" 2>&1) || {
    echo "ERROR: query failed: $out" >&2
    exit 5
  }
  printf '%s\n' "$out"
else
  SQL="SELECT key_prefix,
              array_to_string(scope, ',') AS scope,
              COALESCE(description, '-') AS description,
              created_at::date AS created,
              COALESCE(last_used_at::text, '-') AS last_used,
              CASE WHEN revoked_at IS NULL THEN 'active' ELSE 'revoked' END AS status
       FROM api_keys
       $WHERE
       ORDER BY last_used_at DESC NULLS LAST, created_at DESC"
  psql "$SAVIA_ENTERPRISE_DSN" -P pager=off -P border=2 -c "$SQL" || {
    echo "ERROR: query failed" >&2
    exit 5
  }
fi
