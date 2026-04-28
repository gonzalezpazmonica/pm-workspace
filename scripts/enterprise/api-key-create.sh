#!/usr/bin/env bash
# api-key-create.sh — SPEC-SE-036 Slice 2: API key creation CLI.
#
# Generates a fresh API key (32 bytes urandom, base64url), inserts the
# sha256 hash + key_prefix into api_keys with the requested scope, and
# prints the plaintext **exactly once** to stdout. The plaintext is NEVER
# stored — if the operator loses it, the only recovery is revoke + recreate.
#
# Requires:
#   - SAVIA_ENTERPRISE_DSN     Postgres DSN
#   - psql, openssl
#
# Usage:
#   api-key-create.sh --tenant <uuid> --scope <s1,s2,...> [--desc "..."]
#
# Exit codes:
#   0  ok (plaintext on stdout)
#   2  usage / args invalid
#   3  SAVIA_ENTERPRISE_DSN missing
#   4  psql/openssl missing
#   5  insertion failed (DSN reachable but DB error)
#
# Reference: SPEC-SE-036 (`docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md`)
# Pattern source: `dreamxist/balance` `supabase/migrations/20260404000002_api_keys.sql` (MIT, clean-room)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TENANT=""
SCOPE_CSV=""
DESC=""

usage() {
  sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant) TENANT="$2"; shift 2 ;;
    --scope)  SCOPE_CSV="$2"; shift 2 ;;
    --desc)   DESC="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

# ── Pre-flight ───────────────────────────────────────────────────────────────

if [[ -z "$TENANT" ]]; then
  echo "ERROR: --tenant <uuid> required" >&2
  exit 2
fi

# Loose UUID shape check (no rfc4122 strict — just sanity vs typos)
if ! [[ "$TENANT" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
  echo "ERROR: --tenant must be a UUID (got: $TENANT)" >&2
  exit 2
fi

if [[ -z "$SCOPE_CSV" ]]; then
  echo "ERROR: --scope required (e.g. 'azure-devops:read,github:write')" >&2
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

if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: openssl not found — required for randomness + hashing." >&2
  exit 4
fi

# ── Generate key ─────────────────────────────────────────────────────────────

# 32 random bytes → base64url. Strip padding. Prefix with 'savia_' for grep-ability.
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

RANDOM_PART=$(openssl rand 32 | b64url)
PLAINTEXT="savia_${RANDOM_PART}"
KEY_PREFIX="${PLAINTEXT:0:8}"
KEY_HASH=$(printf '%s' "$PLAINTEXT" | openssl dgst -sha256 -hex | awk '{print $NF}')

# Build SQL scope array literal
SCOPE_ARR=$(printf '%s' "$SCOPE_CSV" | awk -F, '
  BEGIN { printf "ARRAY[" }
  {
    for (i=1;i<=NF;i++) {
      gsub(/^[ \t]+|[ \t]+$/, "", $i)
      if ($i == "") continue
      gsub(/\x27/, "\x27\x27", $i)
      if (printed) printf ","
      printf "\x27%s\x27", $i
      printed=1
    }
  }
  END { printf "]::text[]" }
')

DESC_LIT="NULL"
[[ -n "$DESC" ]] && DESC_LIT="'${DESC//\'/\'\'}'"

INSERT_SQL=$(cat <<SQL
INSERT INTO api_keys (tenant_id, key_prefix, key_hash, scope, description)
VALUES ('${TENANT//\'/\'\'}'::uuid, '$KEY_PREFIX', '$KEY_HASH', $SCOPE_ARR, $DESC_LIT)
RETURNING id::text, key_prefix
SQL
)

OUT=$(psql "$SAVIA_ENTERPRISE_DSN" -At -F'|' -c "$INSERT_SQL" 2>&1) || {
  echo "ERROR: insert failed: $OUT" >&2
  exit 5
}

# ── Output (plaintext shown ONCE) ────────────────────────────────────────────

echo "============================================================"
echo "API KEY CREATED — copy it NOW. It will not be shown again."
echo "============================================================"
echo "  key:      $PLAINTEXT"
echo "  prefix:   $KEY_PREFIX"
echo "  scope:    $SCOPE_CSV"
echo "  tenant:   $TENANT"
echo "  row:      $OUT"
echo "============================================================"
echo "Storage suggestion: ~/.savia/secrets/agent.key (mode 600)"
