#!/bin/bash
# jwt-mint.sh — SPEC-SE-036: API key → JWT ephemeral mint
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md
set -uo pipefail

DB_FILE="${PROJECT_ROOT:-.}/.savia/api-keys.db"
JSON_MODE=0

# ── helpers ────────────────────────────────────────────────────────────────────

_die() { echo "ERROR: $*" >&2; exit 1; }

_require_sqlite() {
  command -v sqlite3 >/dev/null 2>&1 || _die "sqlite3 not found — install sqlite3"
}

_require_openssl() {
  command -v openssl >/dev/null 2>&1 || _die "openssl not found"
}

_ensure_db_dir() {
  local dir
  dir="$(dirname "$DB_FILE")"
  mkdir -p "$dir"
}

_now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_now_epoch() {
  date -u +%s
}

_base64url_encode() {
  # stdin → base64url (no padding)
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

_sha256_hex() {
  # stdin → hex SHA-256
  openssl dgst -sha256 | awk '{print $2}'
}

_hmac_sha256_b64url() {
  # $1=key(hex), $2=data(string) → base64url HMAC-SHA256
  local key_hex="$1"
  local data="$2"
  printf '%s' "$data" \
    | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${key_hex}" -binary \
    | _base64url_encode
}

_json_ok() {
  # output JSON success envelope
  local payload="$1"
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":true,"data":%s}\n' "$payload"
  else
    printf '%s\n' "$payload"
  fi
}

_json_err() {
  local msg="$1"
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":false,"error":"%s"}\n' "$msg"
  else
    echo "ERROR: $msg" >&2
  fi
  exit 1
}

# ── subcommands ────────────────────────────────────────────────────────────────

cmd_init() {
  _require_sqlite
  _ensure_db_dir

  sqlite3 "$DB_FILE" <<'SQL'
CREATE TABLE IF NOT EXISTS api_keys (
  key_prefix TEXT PRIMARY KEY,
  key_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  scope TEXT DEFAULT 'read',
  created_at TEXT NOT NULL,
  status TEXT DEFAULT 'active'
);
CREATE TABLE IF NOT EXISTS api_key_mints (
  mint_id TEXT PRIMARY KEY,
  key_prefix TEXT NOT NULL,
  scope TEXT NOT NULL,
  ttl INTEGER NOT NULL,
  minted_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);
SQL

  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":true,"data":{"tables":["api_keys","api_key_mints"]}}\n'
  else
    echo "schema OK"
  fi
}

cmd_create() {
  _require_sqlite
  _require_openssl
  _ensure_db_dir

  local name="" scope="read"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)  name="$2";  shift 2 ;;
      --scope) scope="$2"; shift 2 ;;
      --json)  JSON_MODE=1; shift ;;
      *) shift ;;
    esac
  done

  [[ -n "$name" ]] || _json_err "missing --name"

  # Generate 32-byte (64 hex char) random key
  local key
  key="$(openssl rand -hex 32)"
  local key_prefix="${key:0:8}"
  local key_hash
  key_hash="$(printf '%s' "$key" | _sha256_hex)"
  local created_at
  created_at="$(_now_iso)"

  sqlite3 "$DB_FILE" \
    "INSERT INTO api_keys (key_prefix, key_hash, name, scope, created_at, status)
     VALUES ('${key_prefix}', '${key_hash}', '${name}', '${scope}', '${created_at}', 'active');"

  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":true,"data":{"key_prefix":"%s","key":"%s","name":"%s","scope":"%s"}}\n' \
      "$key_prefix" "$key" "$name" "$scope"
  else
    printf 'key_prefix: %s\nkey: %s\n' "$key_prefix" "$key"
  fi
}

cmd_list() {
  _require_sqlite

  if [[ "$JSON_MODE" -eq 1 ]]; then
    local rows
    rows="$(sqlite3 -json "$DB_FILE" \
      "SELECT key_prefix, name, scope, created_at, status FROM api_keys ORDER BY created_at;" \
      2>/dev/null || echo '[]')"
    printf '{"ok":true,"data":%s}\n' "$rows"
  else
    sqlite3 -column -header "$DB_FILE" \
      "SELECT key_prefix, name, scope, created_at, status FROM api_keys ORDER BY created_at;"
  fi
}

cmd_revoke() {
  _require_sqlite

  local key_prefix=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) JSON_MODE=1; shift ;;
      *) [[ -z "$key_prefix" ]] && key_prefix="$1"; shift ;;
    esac
  done

  [[ -n "$key_prefix" ]] || _json_err "missing key_prefix argument"

  local rows_affected
  rows_affected="$(sqlite3 "$DB_FILE" \
    "UPDATE api_keys SET status='revoked' WHERE key_prefix='${key_prefix}' AND status='active';
     SELECT changes();")"

  if [[ "$rows_affected" -eq 0 ]]; then
    _json_err "key_prefix '${key_prefix}' not found or already revoked"
  fi

  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":true,"data":{"key_prefix":"%s","status":"revoked"}}\n' "$key_prefix"
  else
    printf 'revoked: %s\n' "$key_prefix"
  fi
}

cmd_mint() {
  _require_sqlite
  _require_openssl

  local key_prefix="" ttl=900 scope=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ttl)   ttl="$2";   shift 2 ;;
      --scope) scope="$2"; shift 2 ;;
      --json)  JSON_MODE=1; shift ;;
      *) [[ -z "$key_prefix" ]] && key_prefix="$1"; shift ;;
    esac
  done

  [[ -n "$key_prefix" ]] || _json_err "missing key_prefix argument"

  # Lookup key — must exist and be active
  local row
  row="$(sqlite3 "$DB_FILE" \
    "SELECT key_hash, scope, status FROM api_keys WHERE key_prefix='${key_prefix}';" \
    2>/dev/null)"

  [[ -n "$row" ]] || _json_err "key_prefix '${key_prefix}' not found"

  local key_hash stored_scope key_status
  key_hash="$(echo "$row" | cut -d'|' -f1)"
  stored_scope="$(echo "$row" | cut -d'|' -f2)"
  key_status="$(echo "$row" | cut -d'|' -f3)"

  [[ "$key_status" == "active" ]] || _json_err "key '${key_prefix}' is ${key_status}"

  # Scope: use stored scope if not overridden (downscoping only)
  local effective_scope="${scope:-$stored_scope}"

  # Build JWT
  local now
  now="$(_now_epoch)"
  local exp=$(( now + ttl ))

  local header_json='{"alg":"HS256","typ":"JWT"}'
  local payload_json
  payload_json="$(printf '{"sub":"%s","scope":"%s","iat":%d,"exp":%d}' \
    "$key_prefix" "$effective_scope" "$now" "$exp")"

  local header_b64
  header_b64="$(printf '%s' "$header_json" | _base64url_encode)"
  local payload_b64
  payload_b64="$(printf '%s' "$payload_json" | _base64url_encode)"

  local signing_input="${header_b64}.${payload_b64}"
  local sig
  sig="$(_hmac_sha256_b64url "$key_hash" "$signing_input")"

  local jwt="${signing_input}.${sig}"

  # Audit trail
  local mint_id
  mint_id="$(openssl rand -hex 16)"
  local minted_at
  minted_at="$(_now_iso)"
  local expires_at
  expires_at="$(date -u -d "@${exp}" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u -r "$exp" +"%Y-%m-%dT%H:%M:%SZ")"

  sqlite3 "$DB_FILE" \
    "INSERT INTO api_key_mints (mint_id, key_prefix, scope, ttl, minted_at, expires_at)
     VALUES ('${mint_id}', '${key_prefix}', '${effective_scope}', ${ttl},
             '${minted_at}', '${expires_at}');"

  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":true,"data":{"jwt":"%s","expires_at":"%s","scope":"%s"}}\n' \
      "$jwt" "$expires_at" "$effective_scope"
  else
    printf '%s\n' "$jwt"
  fi
}

# ── dispatch ───────────────────────────────────────────────────────────────────

# Strip global --json before dispatch
ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--json" ]]; then
    JSON_MODE=1
  else
    ARGS+=("$arg")
  fi
done

[[ "${#ARGS[@]}" -gt 0 ]] || { echo "Usage: jwt-mint.sh <init|create|list|revoke|mint> [options]" >&2; exit 1; }

subcommand="${ARGS[0]}"
rest=("${ARGS[@]:1}")

case "$subcommand" in
  init)   cmd_init   "${rest[@]+"${rest[@]}"}" ;;
  create) cmd_create "${rest[@]+"${rest[@]}"}" ;;
  list)   cmd_list   "${rest[@]+"${rest[@]}"}" ;;
  revoke) cmd_revoke "${rest[@]+"${rest[@]}"}" ;;
  mint)   cmd_mint   "${rest[@]+"${rest[@]}"}" ;;
  *) _die "unknown subcommand: ${subcommand}. Use: init|create|list|revoke|mint" ;;
esac
