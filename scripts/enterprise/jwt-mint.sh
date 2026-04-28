#!/usr/bin/env bash
# jwt-mint.sh — SPEC-SE-036 Slice 1: short-lived JWT mint primitive.
#
# Exchanges a presented API key for a short-lived (default 900s = 15 min)
# JWT signed with $JWT_SIGNING_KEY (HS256). Scope is downscoped from the
# stored key's scope set — never upscoped. Each mint is recorded into
# api_key_mints (append-only, audited via SPEC-SE-037 attach_audit).
#
# Replaces the file-based PAT model (Rule #1 enforcement at infrastructure
# level — `$(cat $PAT_FILE)` was convention; this is cryptographic).
#
# Requires:
#   - SAVIA_ENTERPRISE_DSN     Postgres connection string
#   - JWT_SIGNING_KEY          HMAC secret (HS256), off-repo, 32+ bytes
#   - psql command available
#
# Usage:
#   jwt-mint.sh --key <api_key> --scope azure-devops:read,github:write
#   jwt-mint.sh --key <api_key> --scope github:read --ttl 600
#   jwt-mint.sh --key-stdin --scope github:read    # read api key from stdin
#
# Reference: SPEC-SE-036 (`docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md`)
# Pattern source: `dreamxist/balance` `supabase/migrations/20260404000002_api_keys.sql` (MIT, clean-room)
# CLAUDE.md Rule #1 — moves PAT enforcement from convention → infrastructure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

API_KEY=""
KEY_STDIN=0
SCOPE_CSV=""
TTL=900           # 15 min default per spec (AC-04)
AGENT_ID="${SAVIA_AGENT_ID:-}"
SESSION_ID="${SAVIA_SESSION_ID:-}"

usage() {
  sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key)        API_KEY="$2"; shift 2 ;;
    --key-stdin)  KEY_STDIN=1; shift ;;
    --scope)      SCOPE_CSV="$2"; shift 2 ;;
    --ttl)        TTL="$2"; shift 2 ;;
    --agent-id)   AGENT_ID="$2"; shift 2 ;;
    --session-id) SESSION_ID="$2"; shift 2 ;;
    -h|--help)    usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

# ── Pre-flight ───────────────────────────────────────────────────────────────

if [[ "$KEY_STDIN" -eq 1 ]]; then
  IFS= read -r API_KEY || true
fi

if [[ -z "$API_KEY" ]]; then
  echo "ERROR: --key (or --key-stdin) required" >&2
  exit 2
fi

if [[ -z "$SCOPE_CSV" ]]; then
  echo "ERROR: --scope required (e.g. 'azure-devops:read,github:write')" >&2
  exit 2
fi

# Refuse blatantly invalid TTLs (AC-04: ≤ 900 default; allow 60..3600 explicitly)
if ! [[ "$TTL" =~ ^[0-9]+$ ]] || (( TTL < 60 || TTL > 3600 )); then
  echo "ERROR: --ttl must be integer in [60, 3600] (got: $TTL)" >&2
  exit 2
fi

if [[ -z "${SAVIA_ENTERPRISE_DSN:-}" ]]; then
  echo "ERROR: SAVIA_ENTERPRISE_DSN env not set — JWT mint requires Postgres." >&2
  echo "       In pm-workspace CI this is expected; deploy to Savia Enterprise repo to test live." >&2
  exit 3
fi

if [[ -z "${JWT_SIGNING_KEY:-}" ]]; then
  echo "ERROR: JWT_SIGNING_KEY env not set." >&2
  echo "       Store off-repo (e.g. ~/.savia/secrets/jwt-signing-key, mode 600)." >&2
  echo "       Rotation: see docs/rules/domain/savia-enterprise/agent-jwt-mint.md." >&2
  exit 4
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql not found — install postgresql-client first." >&2
  exit 5
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: openssl not found — required for HMAC-SHA256 signing." >&2
  exit 5
fi

# ── Validate API key + downscope ─────────────────────────────────────────────

# Build SQL array literal for scope CSV, escaping single-quotes.
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

# Escape API key for SQL literal
KEY_ESC="${API_KEY//\'/\'\'}"

# Verify + check subset in a single round trip
VERIFY_SQL=$(cat <<SQL
SELECT
  k.id::text, k.tenant_id::text,
  api_key_scope_is_subset($SCOPE_ARR, k.scope)::text
FROM api_key_verify('$KEY_ESC') k
SQL
)

ROW=$(psql "$SAVIA_ENTERPRISE_DSN" -At -F'|' -c "$VERIFY_SQL" 2>&1) || {
  echo "ERROR: psql verify failed: $ROW" >&2
  exit 6
}

if [[ -z "$ROW" || "$ROW" == "||" ]]; then
  echo "ERROR: API key invalid or revoked" >&2
  exit 7
fi

KEY_ID="${ROW%%|*}"
REST="${ROW#*|}"
TENANT_ID="${REST%%|*}"
IS_SUBSET="${REST##*|}"

if [[ "$IS_SUBSET" != "t" ]]; then
  echo "ERROR: requested scope is NOT a subset of stored scope (downscoping only — never upscoping)" >&2
  exit 8
fi

# ── Sign JWT (HS256) ─────────────────────────────────────────────────────────

NOW=$(date +%s)
EXP=$((NOW + TTL))

# Build scope JSON array
SCOPE_JSON=$(printf '%s' "$SCOPE_CSV" | awk -F, '
  BEGIN { printf "[" }
  {
    for (i=1;i<=NF;i++) {
      gsub(/^[ \t]+|[ \t]+$/, "", $i)
      if ($i == "") continue
      gsub(/"/, "\\\"", $i)
      if (printed) printf ","
      printf "\"%s\"", $i
      printed=1
    }
  }
  END { printf "]" }
')

HEADER_JSON='{"alg":"HS256","typ":"JWT"}'
PAYLOAD_JSON=$(printf '{"tenant_id":"%s","agent_id":"%s","session_id":"%s","scope":%s,"iat":%d,"exp":%d}' \
  "$TENANT_ID" "${AGENT_ID//\"/}" "${SESSION_ID//\"/}" "$SCOPE_JSON" "$NOW" "$EXP")

# base64url encode (RFC 4648 §5): standard b64 with +/ → -_ and trailing = stripped
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

H_B64=$(printf '%s' "$HEADER_JSON" | b64url)
P_B64=$(printf '%s' "$PAYLOAD_JSON" | b64url)
SIGNING_INPUT="${H_B64}.${P_B64}"

SIG=$(printf '%s' "$SIGNING_INPUT" \
  | openssl dgst -sha256 -mac HMAC -macopt "key:$JWT_SIGNING_KEY" -binary \
  | b64url)

JWT="${SIGNING_INPUT}.${SIG}"

# ── Record mint (audited) ────────────────────────────────────────────────────

AGENT_LIT="NULL"
[[ -n "$AGENT_ID" ]] && AGENT_LIT="'${AGENT_ID//\'/\'\'}'"
SESSION_LIT="NULL"
[[ -n "$SESSION_ID" ]] && SESSION_LIT="'${SESSION_ID//\'/\'\'}'"

RECORD_SQL="SELECT api_key_record_mint('$KEY_ID'::uuid, $SCOPE_ARR, $TTL, $AGENT_LIT, $SESSION_LIT)"
MINT_ID=$(psql "$SAVIA_ENTERPRISE_DSN" -At -c "$RECORD_SQL" 2>&1) || {
  echo "ERROR: mint record failed (JWT was signed but not logged): $MINT_ID" >&2
  # We still emit the JWT — recording failure is operationally non-fatal,
  # but the operator MUST see the warning.
  echo "WARNING: continuing despite audit log gap. Investigate api_key_mints table." >&2
}

printf '%s\n' "$JWT"
