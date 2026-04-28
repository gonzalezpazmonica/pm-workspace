#!/usr/bin/env bash
# api-key-revoke.sh — SPEC-SE-036 Slice 2: API key revocation CLI.
#
# Marks an API key as revoked by its 8-char prefix. After revocation, future
# calls to api_key_verify() return NULL — downstream JWTs already minted
# remain valid until their TTL expires (max 60 minutes per SE-036 clamp).
#
# Requires:
#   - SAVIA_ENTERPRISE_DSN     Postgres DSN
#   - psql
#
# Safety layers:
#   - REFUSES without --prefix
#   - REFUSES without --confirm (default is dry-run with row preview)
#   - REFUSES bulk patterns (--prefix all, --prefix *, --prefix '')
#   - Defaults --actor to ${USER:-unknown}; can be overridden for service accounts
#
# Usage:
#   api-key-revoke.sh --prefix <prefix>                       # dry-run
#   api-key-revoke.sh --prefix <prefix> --confirm             # actually revoke
#   api-key-revoke.sh --prefix <prefix> --actor svc-rotation --confirm
#
# Exit codes:
#   0  ok
#   2  usage / args invalid
#   3  SAVIA_ENTERPRISE_DSN missing
#   4  psql missing
#   5  no active key with that prefix
#   6  bulk-revoke or self-purge attempt refused
#   7  database error
#
# Reference: SPEC-SE-036 (`docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md`)
# Pattern source: `dreamxist/balance` (MIT, clean-room)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PREFIX=""
ACTOR="${USER:-unknown}"
CONFIRM=0

usage() {
  sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)  PREFIX="$2"; shift 2 ;;
    --actor)   ACTOR="$2"; shift 2 ;;
    --confirm) CONFIRM=1; shift ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

# ── Pre-flight ───────────────────────────────────────────────────────────────

if [[ -z "$PREFIX" ]]; then
  echo "ERROR: --prefix required" >&2
  usage
fi

# Refuse bulk-revoke patterns
case "$PREFIX" in
  ""|"*"|"all"|"%")
    echo "ERROR: bulk revoke refused (got: '$PREFIX')" >&2
    exit 6
    ;;
esac

# Sanity: prefix should be the 8-char key_prefix exactly. Reject obvious wildcards.
if [[ "$PREFIX" == *"*"* || "$PREFIX" == *"%"* ]]; then
  echo "ERROR: wildcard refused in --prefix" >&2
  exit 6
fi

if [[ -z "${SAVIA_ENTERPRISE_DSN:-}" ]]; then
  echo "ERROR: SAVIA_ENTERPRISE_DSN env not set." >&2
  exit 3
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql not found." >&2
  exit 4
fi

# ── Pre-revoke preview ───────────────────────────────────────────────────────

PREFIX_ESC="${PREFIX//\'/\'\'}"
ACTOR_ESC="${ACTOR//\'/\'\'}"

PREVIEW_SQL="SELECT key_prefix, tenant_id::text,
                    array_to_string(scope, ',') AS scope,
                    COALESCE(description, '-') AS description,
                    CASE WHEN revoked_at IS NULL THEN 'active' ELSE 'already revoked at ' || revoked_at::text END AS status
             FROM api_keys
             WHERE key_prefix = '$PREFIX_ESC'"
PREVIEW=$(psql "$SAVIA_ENTERPRISE_DSN" -P pager=off -P border=2 -c "$PREVIEW_SQL" 2>&1) || {
  echo "ERROR: preview query failed: $PREVIEW" >&2
  exit 7
}

# Check whether the key exists + is active
COUNT_SQL="SELECT count(*) FROM api_keys WHERE key_prefix = '$PREFIX_ESC' AND revoked_at IS NULL"
COUNT=$(psql "$SAVIA_ENTERPRISE_DSN" -At -c "$COUNT_SQL" 2>&1) || {
  echo "ERROR: count query failed: $COUNT" >&2
  exit 7
}

if [[ "$COUNT" -eq 0 ]]; then
  echo "$PREVIEW"
  echo "ERROR: no active key with prefix '$PREFIX'" >&2
  exit 5
fi

echo "Pre-revoke preview:"
echo "$PREVIEW"
echo "Actor: $ACTOR"

if [[ "$CONFIRM" -ne 1 ]]; then
  echo ""
  echo "DRY-RUN. Re-run with --confirm to proceed."
  exit 0
fi

# ── Execute revoke ───────────────────────────────────────────────────────────

REVOKE_SQL="CALL api_key_revoke('$PREFIX_ESC', '$ACTOR_ESC')"
RESULT=$(psql "$SAVIA_ENTERPRISE_DSN" -At -c "$REVOKE_SQL" 2>&1) || {
  echo "ERROR: revoke failed: $RESULT" >&2
  exit 7
}

echo "OK: revoked key with prefix '$PREFIX' (actor: $ACTOR)."
echo "Note: JWTs already minted from this key remain valid until their TTL expires (max 60 min)."
